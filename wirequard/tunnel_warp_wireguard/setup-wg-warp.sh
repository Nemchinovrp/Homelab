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

# === 1. Установка warp-cli по официальному гайду Cloudflare (2025) ===
if ! command -v warp-cli &> /dev/null; then
    echo "[*] Установка Cloudflare WARP..."

    # Удаляем старые артефакты (на всякий случай)
    rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    rm -f /etc/apt/sources.list.d/cloudflare-client.list

    # Добавляем GPG-ключ (официальный способ 2025)
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
        gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

    # Добавляем репозиторий
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/cloudflare-client.list

    # Устанавливаем
    apt-get update
    apt-get install -y cloudflare-warp
fi

# === 2. Очистка старого namespace (если существует) ===
ip netns del "$WARP_NS" 2>/dev/null || true
ip link delete "$VETH_HOST" 2>/dev/null || true

# === 3. Создание veth-пары и network namespace ===
echo "[*] Создание network namespace '$WARP_NS'..."
ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
ip link set "$VETH_HOST" up
ip addr add "$HOST_GW/24" dev "$VETH_HOST"

ip link set "$VETH_NS" netns "$WARP_NS"
ip netns exec "$WARP_NS" ip addr add "$WARP_GW/24" dev "$VETH_NS"
ip netns exec "$WARP_NS" ip link set "$VETH_NS" up
ip netns exec "$WARP_NS" ip link set lo up

# === 4. Настройка маршрутизации на хосте ===
echo "[*] Настройка IP forwarding и правил iptables..."
sysctl -w net.ipv4.ip_forward=1

# Правило NAT будет добавлено через wg0.conf (PostUp), поэтому здесь только включение forward
iptables -I FORWARD -i "$VETH_HOST" -j ACCEPT
iptables -I FORWARD -o "$VETH_HOST" -j ACCEPT

# === 5. Запуск warp-svc в namespace ===
echo "[*] Запуск WARP в namespace..."
ip netns exec "$WARP_NS" warp-svc &

# Ждём, пока сервис стартует
sleep 5

# Проверяем статус
if ! ip netns exec "$WARP_NS" warp-cli status &>/dev/null; then
    echo "[!] Не удалось запустить warp-cli в namespace."
    exit 1
fi

# Регистрация (если нужно)
if ! ip netns exec "$WARP_NS" warp-cli status | grep -q "Registered"; then
    echo
    echo "[!] Требуется первоначальная регистрация."
    echo "Выполните команды вручную:"
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
echo "[✓] Готово! WARP запущен в namespace '$WARP_NS'."
echo
echo "Теперь обновите ваш wg0.conf, как указано в инструкции:"
echo "  - Замените MASQUERADE на SNAT --to-source $WARP_GW"
echo "  - Добавьте FORWARD между wg0 и $VETH_HOST"
echo
echo "После этого выполните:"
echo "  wg-quick down wg0 && wg-quick up wg0"