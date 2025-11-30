#!/bin/bash
set -e

# === Настройки ===
WG_CLIENT_SUBNET="10.77.33.0/24"
WG_CLIENT_IFACE="wg0"
WARP_IFACE="wgcf"

echo "[*] Проверка root..."
[ "$EUID" -ne 0 ] && { echo "Запустите от root"; exit 1; }

# === 1. Установка зависимостей ===
echo "[*] Установка зависимостей..."
apt update
apt install -y curl wget iptables resolvconf


# === 2. Установка wgcf (прямая ссылка) ===
echo "[*] Установка wgcf..."
if [ ! -f /usr/local/bin/wgcf ]; then
    echo "[*] Скачивание wgcf-linux-amd64..."
    wget -O /usr/local/bin/wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.29/wgcf_2.2.29_linux_amd64
    if [ $? -ne 0 ]; then
        echo "❌ Не удалось скачать wgcf. Проверьте доступ к GitHub."
        exit 1
    fi
    chmod +x /usr/local/bin/wgcf
fi

# === 3. Генерация учётных данных WARP ===
if [ ! -f wgcf-account.toml ]; then
    echo "[*] Регистрация устройства в WARP..."
    /usr/local/bin/wgcf register --accept-tos
fi

if [ ! -f wgcf-profile.conf ]; then
    echo "[*] Генерация WireGuard-профиля WARP..."
    /usr/local/bin/wgcf generate
fi

# === 4. Настройка WARP-интерфейса ===
echo "[*] Настройка WARP-интерфейса..."
ip link delete "$WARP_IFACE" 2>/dev/null || true

cp wgcf-profile.conf "/etc/wireguard/${WARP_IFACE}.conf"
chmod 600 "/etc/wireguard/${WARP_IFACE}.conf"

wg-quick up "$WARP_IFACE"

# === 5. Настройка IP forwarding и iptables ===
echo "[*] Настройка маршрутизации..."

# Включить IP forwarding
echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.conf
sysctl -p

# Очистить старые правила (если есть)
iptables -t nat -D POSTROUTING -s "$WG_CLIENT_SUBNET" ! -d "$WG_CLIENT_SUBNET" -o "$WARP_IFACE" -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i "$WG_CLIENT_IFACE" -o "$WARP_IFACE" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$WARP_IFACE" -o "$WG_CLIENT_IFACE" -j ACCEPT 2>/dev/null || true

# Применить новые правила
iptables -t nat -A POSTROUTING -s "$WG_CLIENT_SUBNET" ! -d "$WG_CLIENT_SUBNET" -o "$WARP_IFACE" -j MASQUERADE
iptables -A FORWARD -i "$WG_CLIENT_IFACE" -o "$WARP_IFACE" -j ACCEPT
iptables -A FORWARD -i "$WARP_IFACE" -o "$WG_CLIENT_IFACE" -j ACCEPT

# === 6. Обновление wg0.conf ===
WG0_CONF="/etc/wireguard/wg0.conf"

# Удаляем старые правила с ens3 (если остались)
sed -i '/MASQUERADE.*ens3/d' "$WG0_CONF"
sed -i '/FORWARD.*ens3/d' "$WG0_CONF"

# Добавляем новые правила, если их нет
if ! grep -q "MASQUERADE.*$WARP_IFACE" "$WG0_CONF"; then
    cat <<EOF >> "$WG0_CONF"

# === Routing via WARP (wgcf) ===
PostUp = iptables -t nat -A POSTROUTING -s $WG_CLIENT_SUBNET ! -d $WG_CLIENT_SUBNET -o $WARP_IFACE -j MASQUERADE
PostUp = iptables -A FORWARD -i $WG_CLIENT_IFACE -o $WARP_IFACE -j ACCEPT
PostUp = iptables -A FORWARD -i $WARP_IFACE -o $WG_CLIENT_IFACE -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s $WG_CLIENT_SUBNET ! -d $WG_CLIENT_SUBNET -o $WARP_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_CLIENT_IFACE -o $WARP_IFACE -j ACCEPT
PostDown = iptables -D FORWARD -i $WARP_IFACE -o $WG_CLIENT_IFACE -j ACCEPT
EOF
fi

# === 7. Перезапуск клиентского WireGuard ===
echo "[*] Перезапуск wg0..."
wg-quick down "$WG_CLIENT_IFACE" 2>/dev/null || true
wg-quick up "$WG_CLIENT_IFACE"

# === 8. Итог ===
echo
echo "[✓] УСПЕШНО! "
echo "Клиенты из $WG_CLIENT_SUBNET теперь выходят в интернет через Cloudflare WARP."
echo
echo "Проверка с клиента:"
echo "  curl -4 ifconfig.me"
echo "Ожидаемый результат: IP из диапазона Cloudflare (например, 104.16.x.x)"
echo
echo "Файлы:"
echo "  WARP-конфиг: /etc/wireguard/${WARP_IFACE}.conf"
echo "  Клиентский конфиг: $WG0_CONF"