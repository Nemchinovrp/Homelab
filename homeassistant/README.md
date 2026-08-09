Посмотреть логи:
docker compose logs -f homeassistant

После запуска открывай:
http://IP_СЕРВЕРА:8123

network_mode: host здесь выбран намеренно. Для Home Assistant это обычно самый беспроблемный вариант на Linux, особенно если нужны автоматическое обнаружение устройств, mDNS/Bonjour, Chromecast, HomeKit и прочие устройства локальной сети.
Для обновления:
docker compose pull
docker compose up -d
docker image prune -f