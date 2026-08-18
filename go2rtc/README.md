Запускаю на маке и адрес веб панели http://127.0.0.1:1984/


Для автоматического запуска каждые 15 минут:
crontab -e

Добавь:
*/15 * * * * /Users/roman/IdeaProjects/homelab/go2rtc/refresh-dsi.sh >> /tmp/refresh-dsi.log 2>&1