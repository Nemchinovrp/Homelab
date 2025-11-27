# Установка Squid:
sudo apt update
sudo apt install squid apache2-utils
sudo apt install wireguard iptables-persistent netfilter-persistent

# Резервное копирование оригинального конфига:
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Основной конфиг Squid:
/etc/squid/squid.conf:

------------------------------------------------------------
# Установка Cloudflare WARP:
# Добавляем репозиторий Cloudflare
curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

sudo apt update
sudo apt install cloudflare-warp

# Регистрируем и настраиваем
warp-cli register
warp-cli set-mode proxy
warp-cli connect

# Проверяем
warp-cli status
warp-cli get-proxy-port
------------------------------------------------------------
# Настройка WireGuard

# Генерация ключей:

cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client1_private.key | wg pubkey > client1_public.key

# Скрипт настройки iptables
/etc/wireguard/setup-squid-routing.sh:

# Делаем исполняемым и запускаем:
sudo chmod +x /etc/wireguard/setup-squid-routing.sh
sudo /etc/wireguard/setup-squid-routing.sh


# Конфигурация клиента WireGuard
/etc/wireguard/client.conf:

Запуск и управление сервисами
Создаем systemd сервис для управления:
/etc/systemd/system/wg-squid.service:

# Включаем автозапуск:

sudo systemctl daemon-reload
sudo systemctl enable wg-squid
sudo systemctl enable warp-svc

# Запускаем
sudo systemctl start warp-svc
sudo systemctl start wg-squid

# Расширенная конфигурация Squid
Для лучшего контроля создаем дополнительные ACL:
/etc/squid/conf.d/acl.conf:

Создаем списки доменов:

# Рекламные домены
sudo mkdir -p /etc/squid
curl -s https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts | \
grep '^0.0.0.0' | awk '{print $2}' | \
sudo tee /etc/squid/ads.domains

# Домены без WARP (пример)
echo -e "google.com\nyoutube.com\ngithub.com" | sudo tee /etc/squid/nowarp.domains

# Мониторинг и логи
Настройка расширенного логирования:
/etc/squid/conf.d/logging.conf:

# Скрипт мониторинга:
/usr/local/bin/monitor-squid-warp.sh:

Добавляем в cron:

echo "*/3 * * * * root /usr/local/bin/monitor-squid-warp.sh" | sudo tee /etc/cron.d/squid-warp-monitor
sudo chmod +x /usr/local/bin/monitor-squid-warp.sh

# Тестирование работы
## На сервере проверяем:

# Статус сервисов
sudo systemctl status squid warp-svc wg-quick@wg0

# Прослушиваемые порты
sudo netstat -tulpn | grep -E '(3128|40000|51820)'

# Логи Squid
sudo tail -f /var/log/squid/access.log

# Логи WireGuard
sudo wg show


## На клиенте:
# Подключаемся к WireGuard
sudo wg-quick up client.conf

# Проверяем IP (должен быть Cloudflare)
curl -s ifconfig.me

# Тестируем прокси
curl -s --proxy http://10.0.0.1:3128 ifconfig.me

# Проверяем DNS
nslookup google.com






Оптимизация производительности
/etc/squid/conf.d/performance.conf:

