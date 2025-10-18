Проект - https://github.com/WGDashboard/WGDashboard.git

docker run --privileged --cap-add=NET_ADMIN --cap-add=SYS_MODULE -v /etc/wireguard:/etc/wireguard -p 10086:10086 cffd8e7864fd

sudo wg show


docker run -d --name wgdashboard --restart unless-stopped -p 10086:10086/tcp -p 51820:51820/udp --cap-add NET_ADMIN ghcr.io/wgdashboard/wgdashboard:latest