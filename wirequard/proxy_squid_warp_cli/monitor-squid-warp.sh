#!/bin/bash

LOG_FILE="/var/log/squid-monitor.log"

echo "$(date): Checking services..." >> $LOG_FILE

# Проверка Squid
if ! systemctl is-active --quiet squid; then
    echo "Squid is down, restarting..." >> $LOG_FILE
    systemctl restart squid
fi

# Проверка WARP
WARP_STATUS=$(warp-cli status | grep Status | cut -d':' -f2 | tr -d ' ')
if [ "$WARP_STATUS" != "Connected" ]; then
    echo "WARP disconnected, reconnecting..." >> $LOG_FILE
    warp-cli disconnect
    sleep 2
    warp-cli connect
fi

# Проверка WireGuard
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "WireGuard is down, restarting..." >> $LOG_FILE
    systemctl restart wg-quick@wg0
fi

# Проверка портов
if ! netstat -tuln | grep ":3128 " > /dev/null; then
    echo "Squid port not listening" >> $LOG_FILE
fi

if ! netstat -tuln | grep ":40000 " > /dev/null; then
    echo "WARP proxy port not listening" >> $LOG_FILE
fi