Установка warp-cli

Установка redsocks
sudo apt update
sudo apt install redsocks -y


/etc/redsocks.conf

sudo systemctl restart redsocks
sudo systemctl enable redsocks


wg-quick down wg0
wg-quick up wg0


Обнови wg0.conf — добавь правила iptables