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

------------------------------------------------------
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
------------------------------------------------------


# Проверка конфигурации
sudo sing-box check -c /etc/sing-box/config.json

# Перезагрузка systemd
sudo systemctl daemon-reload

# Включение автозапуска
sudo systemctl enable sing-box

# Запуск сервиса
sudo systemctl start sing-box

# Проверка статуса
sudo systemctl status sing-box

# Просмотр логов
sudo journalctl -u sing-box -f