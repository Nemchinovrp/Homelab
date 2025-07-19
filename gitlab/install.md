Поднимаем Gitlab и Gitlab-Runner на docker



Создадим каталог с файлом docker-compose.yml

# mkdir -p /data/docker/gitlab
# vi gitlab\docker-compose.yml



Создадим структуру папок для образов:

# mkdir -p /data/docker/gitlab/var/opt/gitlab
# mkdir -p /data/docker/gitlab/var/log/gitlab
# mkdir -p /data/docker/gitlab/etc/gitlab-runner
# mkdir -p /data/docker/gitlab/var/run/docker.sock



Сам файл:

# cat docker-compose.yml
version: '3.5'
services:
gitlab:
image: gitlab/gitlab-ce:latest
hostname: 10.106.65.24
restart: unless-stopped
environment:
GITLAB_OMNIBUS_CONFIG: |
gitlab_rails['gitlab_shell_ssh_port'] = 8822
ports:
- "8000:80"
- "8822:22"
volumes:
- /data/docker/gitlab/etc/gitlab:/etc/gitlab
- /data/docker/gitlab/var/opt/gitlab:/var/opt/gitlab
- /data/docker/gitlab/var/log/gitlab:/var/log/gitlab
networks:
- gitlab_net

gitlab-runner:
image: gitlab/gitlab-runner:alpine
restart: unless-stopped
depends_on:
- gitlab
volumes:
- /data/docker/gitlab/etc/gitlab-runner:/etc/gitlab-runner
- /data/docker/gitlab/var/run/docker.sock:/var/run/docker.sock
networks:
- gitlab_net

networks:
gitlab_net:



Стартуем:

# docker-compose up -d --force-recreate && docker-compose ps



Доступ к Gitlab из браузера через порт 8000 и через SSH через порт 8822





Узнать пароль для учетки root из web-панели GitLab:

# docker exec -it gitlab_gitlab_1 grep 'Password:' /etc/gitlab/initial_root_password



Убить все: laugh
# docker-compose stop && docker-compose rm -f 


Password: l4h+XMdFQ/AVBIv4Si9wsYQHTbB0CjXYsykUrcMxCgI=

docker exec -it gitlab /bin/bash