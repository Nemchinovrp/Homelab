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


Обнови wg0.conf — добавь правила iptables