Проект - https://github.com/WGDashboard/WGDashboard.git

docker run --privileged --cap-add=NET_ADMIN --cap-add=SYS_MODULE -v /etc/wireguard:/etc/wireguard -p 10086:10086 cffd8e7864fd

sudo wg show


docker run -d --name wgdashboard --restart unless-stopped -p 10086:10086/tcp -p 51820:51820/udp --cap-add NET_ADMIN ghcr.io/wgdashboard/wgdashboard:latest


docker run -d --name wgdashboard --restart unless-stopped -p 10086:10086/tcp -p 53713:53713/udp --cap-add NET_ADMIN ghcr.io/wgdashboard/wgdashboard:latest

docker stop $(docker ps -qa) && docker rm $(docker ps -qa) && docker rmi -f $(docker images -qa) && docker volume rm $(docker volume ls -q) && docker network rm $(docker network ls -q)
еще один проект - https://github.com/ngoduykhanh/wireguard-ui.git
