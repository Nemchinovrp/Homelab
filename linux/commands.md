ssh-copy-id root@85.198.110.167
nano /etc/ssh/sshd_config  --- отключить достурп по паролю #PasswordAuthentication yes
sudo service ssh restart
----------------------------------

netstat -tulpn : процессы которые слушают сетевые порты
ss -lntu : процессы на порты
netstat -rn : сетевые маршруты
ip r : сетевые маршруты
traceroute 8.8.8.8 : маршрут трафика
mtr 8.8.8.8 : онлайн маршрутизация
tcpdump -i any port 9100 -nn xc
df -h :место на диске
-------------------------------------

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc


# Add the repository to Apt sources:
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin