#!/bin/bash
set -e

# === Настройки ===
WG_SUBNET="10.8.0.0/24"
WG_IP="10.8.0.1"
WARP_NS="warpns"
VETH_HOST="wg-warp"
VETH_NS="eth0-warp"
WARP_GW="10.200.200.2"
HOST_GW="10.200.200.1"
WARP_ROUTE_TABLE="100"

echo "[*] Проверка root..."
[ "$EUID" -ne 0 ] && { echo "Запустите от root"; exit 1; }

# === 1. Установка warp-cli (если не установлен) ===
if ! command -v warp-cli &> /dev/null; then
    echo "[*] Установка warp-cli..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyrings.gpg] https://pkg.cloudflareclient.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt update
    apt install -y cloudflare-warp
fi

# === 2. Удаление старого namespace (если есть) ===
ip netns del $WARP_NS 2>/dev/null || true
ip link delete $VETH_HOST 2>/dev/null || true

# === 3. Создание veth-пары и namespace ===
echo "[*] Создание network namespace и veth..."
ip link add $VETH_HOST type veth peer name $VETH_NS
ip link set $VETH_HOST up
ip addr add $HOST_GW/24 dev $VETH_HOST

ip link set $VETH_NS netns $WARP_NS
ip netns exec $WARP_NS ip addr add $WARP_GW/24 dev $VETH_NS
ip netns exec $WARP_NS ip link set $VETH_NS up
ip netns exec $WARP_NS ip link set lo up

# === 4. Включение IP forwarding и NAT ===
echo "[*] Настройка маршрутизации..."
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s $WG_SUBNET ! -d $WG_SUBNET -j SNAT --to-source $WARP_GW

# === 5. Запуск WARP в namespace ===
echo "[*] Запуск WARP в namespace..."
# Запускаем warp-сервис вручную в namespace
ip netns exec $WARP_NS warp-svc &

# Ждём, пока сервис запустится
sleep 5

# Регистрация и подключение (если ещё не зарегистрирован)
if ! ip netns exec $WARP_NS warp-cli status | grep -q "Registered"; then
    echo "[!] Требуется первоначальная регистрация."
    echo "Выполните вручную:"
    echo "  ip netns exec $WARP_NS warp-cli register"
    echo "После этого запустите:"
    echo "  ip netns exec $WARP_NS warp-cli set mode tun"
    echo "  ip netns exec $WARP_NS warp-cli connect"
    exit 1
fi

# Подключаемся (если не подключено)
if ! ip netns exec $WARP_NS warp-cli status | grep -q "Connected"; then
    ip netns exec $WARP_NS warp-cli connect
fi

# Включаем IP forwarding внутри namespace
ip netns exec $WARP_NS sysctl -w net.ipv4.ip_forward=1

echo "[*] Готово!"
echo "Теперь убедитесь, что в конфигурации WireGuard (wg0.conf) есть:"
echo
echo "PostUp = iptables -t nat -A POSTROUTING -s $WG_SUBNET ! -d $WG_SUBNET -j SNAT --to-source $WARP_GW"
echo "PostDown = iptables -t nat -D POSTROUTING -s $WG_SUBNET ! -d $WG_SUBNET -j SNAT --to-source $WARP_GW"
echo
echo "И перезапустите WireGuard: wg-quick down wg0 && wg-quick up wg0"