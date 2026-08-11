Зайди в VM через Proxmox → VM → Console и выполни:
sudo systemctl status ssh

Если получишь что-то вроде Unit ssh.service could not be found, установи SSH-сервер:
sudo apt update
sudo apt install openssh-server
sudo systemctl enable --now ssh

После этого проверь:
sudo systemctl status ssh