#!/bin/bash
set -e

# === Настройки ===
WG_SUBNET="10.77.33.0/24"
WARP_NS="warpns"
VETH_HOST="wg-warp"
VETH_NS="eth0-warp"
WARP_GW="10.200.200.2"
HOST_GW="10.200.200.1"

echo "[*] Проверка root..."
[ "$EUID" -ne 0 ] && { echo "Запустите от root"; exit 1; }

# === 1. Установка Cloudflare WARP (официальный способ 2025) ===
if ! command -v warp-cli &> /dev/null; then
    echo "[*] Установка Cloudflare WARP..."

    # Удаляем старый ключ и репозиторий (на всякий случай)
    rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    rm -f /etc/apt/sources.list.d/cloudflare-client.list

    # Добавляем GPG-ключ (с --yes, как требуется в 2025)
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
        gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

    # Добавляем репозиторий
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/cloudflare-client.list

    # Устанавливаем
    apt-get update
    apt-get install -y cloudflare-warp
fi

# === 2. Очистка старых компонентов ===
ip netns del "$WARP_NS" 2>/dev/null || true
ip link delete "$VETH_HOST" 2>/dev/null || true
rm -rf /var/lib/cloudflare-warp/ 2>/dev/null || true

# === 3. Создание veth-пары и network namespace ===
echo "[*] Создание network namespace и veth-пары..."
ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
ip link set "$VETH_HOST" up
ip addr add "$HOST_GW/24" dev "$VETH_HOST"

ip netns add "$WARP_NS"
ip link set "$VETH_NS" netns "$WARP_NS"

ip netns exec "$WARP_NS" ip addr add "$WARP_GW/24" dev "$VETH_NS"
ip netns exec "$WARP_NS" ip link set "$VETH_NS" up
ip netns exec "$WARP_NS" ip link set lo up

# === 4. Настройка маршрутизации на хосте ===
sysctl -w net.ipv4.ip_forward=1
iptables -I FORWARD -i "$VETH_HOST" -j ACCEPT
iptables -I FORWARD -o "$VETH_HOST" -j ACCEPT

# === 5. Регистрация WARP ВНУТРИ namespace (автоматически принимает ToS) ===
if ! ip netns exec "$WARP_NS" warp-cli status &>/dev/null || \
   ! ip netns exec "$WARP_NS" warp-cli status | grep -q "Registered"; then

    echo
    echo "[!] Требуется первоначальная регистрация WARP."
    echo "Следуйте инструкциям ниже:"
    echo
    echo "  ip netns exec $WARP_NS warp-cli register"
    echo
    echo "После регистрации выполните:"
    echo "  ip netns exec $WARP_NS warp-cli set mode tun"
    echo "  ip netns exec $WARP_NS warp-cli connect"
    echo
    exit 1
fi

# Подключаемся, если не подключено
if ! ip netns exec "$WARP_NS" warp-cli status | grep -q "Connected"; then
    echo "[*] Подключение к WARP..."
    ip netns exec "$WARP_NS" warp-cli connect
fi

# Включаем IP forwarding внутри namespace
ip netns exec "$WARP_NS" sysctl -w net.ipv4.ip_forward=1

echo
echo "[✓] Настройка завершена!"
echo "WARP работает в namespace '$WARP_NS' и принимает трафик от $WG_SUBNET."
echo
echo "Убедитесь, что в вашем wg0.conf используется SNAT на $WARP_GW:"
echo "  iptables -t nat -A POSTROUTING -s $WG_SUBNET ! -d $WG_SUBNET -j SNAT --to-source $WARP_GW"
echo
echo "После этого перезапустите WireGuard:"
echo "  wg-quick down wg0 && wg-quick up wg0"