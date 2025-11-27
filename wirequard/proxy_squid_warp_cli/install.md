Установка Squid:
sudo apt update
sudo apt install squid apache2-utils

Резервное копирование оригинального конфига:
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

Основной конфиг Squid:
/etc/squid/squid.conf:

------------------------------------------------------------
Установка Cloudflare WARP:
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
Настройка WireGuard

Генерация ключей:

cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client1_private.key | wg pubkey > client1_public.key

Скрипт настройки iptables
/etc/wireguard/setup-squid-routing.sh:

Делаем исполняемым и запускаем:
sudo chmod +x /etc/wireguard/setup-squid-routing.sh
sudo /etc/wireguard/setup-squid-routing.sh


Конфигурация клиента WireGuard
/etc/wireguard/client.conf:

Запуск и управление сервисами
Создаем systemd сервис для управления:
/etc/systemd/system/wg-squid.service:

Включаем автозапуск: