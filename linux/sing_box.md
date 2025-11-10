# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка необходимых зависимостей
sudo apt install -y curl gnupg

# Добавление GPG ключа и репозитория sing-box
curl -fsSL https://sing-box.app/install.sh | sudo bash

# Установка sing-box
sudo apt install -y sing-box

# Проверка версии
sing-box version

# Проверка доступных команд
sing-box --help

# Создание конфигурационной директории:
sudo mkdir -p /etc/sing-box

# Создание базового конфигурационного файла:
sudo nano /etc/sing-box/config.json

sudo systemctl status sing-box

# Если сервис не создан автоматически, создайте его:
sudo nano /etc/systemd/system/sing-box.service

