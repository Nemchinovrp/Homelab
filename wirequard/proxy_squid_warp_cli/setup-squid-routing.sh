#!/bin/bash

# Интерфейсы
WG_INTERFACE="wg0"
SQUID_PORT="3128"
WARP_PORT="40000"

# Очистка правил
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

# Базовые политики
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешаем локальный трафик
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешаем установленные соединения
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# WireGuard порт
iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# SSH (если нужен)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Squid порт (для отладки)
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT

# Разрешаем форвардинг для WireGuard
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT

# Маскарадинг для интернета
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# ПРОЗРАЧНЫЙ ПРОКСИ ДЛЯ WIREGUARD КЛИЕНТОВ
# HTTP трафик -> Squid
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 80 -j REDIRECT --to-port $SQUID_PORT
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 443 -j REDIRECT --to-port $SQUID_PORT

# Исключаем DNS из прокси (важно!)
iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j ACCEPT
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 53 -j ACCEPT

# Сохраняем правила
netfilter-persistent save
netfilter-persistent reload

echo "✅ iptables rules configured for Squid transparent proxy"