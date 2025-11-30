Установка warp-cli

Установка redsocks
sudo apt update
sudo apt install redsocks -y


/etc/redsocks.conf

sudo systemctl restart redsocks
sudo systemctl enable redsocks

curl -O https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh
chmod +x wireguard-install.sh
./wireguard-install.sh

wg-quick down wg0
wg-quick up wg0

sudo wg show

Обнови wg0.conf — добавь правила iptables

------------
отладка

Проверь, слушает ли WARP SOCKS5-порт
ss -tuln | grep 40000


Проверь, запущен ли redsocks и слушает ли он
sudo systemctl status redsocks
ss -tuln | grep 12345

sudo journalctl -u redsocks -n 50


# redsocks принимает HTTP CONNECT, но не SOCKS
# Поэтому тестируем так:
curl --proxy http://127.0.0.1:12345 https://ifconfig.me