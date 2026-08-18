#!/usr/bin/env bash

set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

PROJECT_DIR="/Users/roman/IdeaProjects/homelab/go2rtc"
ENV_FILE="$PROJECT_DIR/.env"
SECRET_FILE="$PROJECT_DIR/.dsi.env"
LOCK_DIR="$PROJECT_DIR/.refresh-dsi.lock"

VARIABLE_NAME="DSI_173481138_URL"
CAMERA_ID="18894"

cleanup() {
  if [[ -n "${TEMPORARY_FILE:-}" && -f "$TEMPORARY_FILE" ]]; then
    rm -f "$TEMPORARY_FILE"
  fi

  if [[ -d "$LOCK_DIR" ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cd "$PROJECT_DIR"

# Не допускаем одновременный запуск нескольких копий скрипта.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Обновление уже выполняется"
  exit 0
fi

for command_name in curl jq awk docker; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Не найдена команда: $command_name"
    exit 1
  fi
done

if [[ ! -f "$SECRET_FILE" ]]; then
  echo "Не найден файл с cookie: $SECRET_FILE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Не найден файл: $ENV_FILE"
  exit 1
fi

# В .dsi.env должна быть строка:
# DSI_COOKIE='html5=1; soundVolume=0; PHPSESSIDFPST=...'
#
# shellcheck disable=SC1090
source "$SECRET_FILE"

if [[ -z "${DSI_COOKIE:-}" ]]; then
  echo "Переменная DSI_COOKIE отсутствует в $SECRET_FILE"
  exit 1
fi

echo "Запрашиваю свежую ссылку камеры DSI..."

cache_buster="$(date +%s)000"

response="$(
  curl --fail --silent --show-error \
    --get \
    --url "https://video.dsi.ru/account/camera/${CAMERA_ID}/url.html" \
    --data-urlencode 'time=' \
    --data-urlencode 'timeZoneOffset=10800' \
    --data-urlencode 'format=hls' \
    --data-urlencode "_=${cache_buster}" \
    -H 'Accept: application/json, text/javascript, */*; q=0.01' \
    -H "Referer: https://video.dsi.ru/account/camera/${CAMERA_ID}/view.html?backPage=5" \
    -H 'User-Agent: Mozilla/5.0' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -b "$DSI_COOKIE"
)"

if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
  echo "DSI вернул ответ, который не является JSON"
  exit 1
fi

rtsp_url="$(
  printf '%s' "$response" |
    jq -er '
      select(.Error == false and .Status == true)
      | select(.URL != null and .URL != "")
      | .URL
    ' |
    tr -d '\r\n'
)"

hls_url="$(
  printf '%s' "$rtsp_url" |
    sed 's|/rtsp/|/hls/|'
)"

hls_url="${hls_url%/}/playlist.m3u8"

if [[ ! "$hls_url" =~ ^https://[^/:]+:[0-9]+/hls/.+/playlist\.m3u8$ ]]; then
  echo "DSI вернул адрес неожиданного формата"
  exit 1
fi

echo "Проверяю HLS-поток..."

playlist="$(
  curl --fail --silent --show-error --http1.1 \
    --url "$hls_url" \
    -H 'Accept: */*' \
    -H 'Origin: https://video.dsi.ru' \
    -H 'Referer: https://video.dsi.ru/' \
    -H 'User-Agent: Mozilla/5.0'
)"

if ! printf '%s\n' "$playlist" | grep -q '^#EXTM3U'; then
  echo "Полученный адрес не вернул корректный HLS-плейлист"
  exit 1
fi

current_url="$(
  sed -n "s/^${VARIABLE_NAME}=//p" "$ENV_FILE" |
    head -n 1
)"

if [[ "$current_url" == "$hls_url" ]]; then
  echo "Ссылка не изменилась — перезапуск не требуется"
  exit 0
fi

echo "Обновляю $VARIABLE_NAME в .env..."

TEMPORARY_FILE="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"

awk \
  -v key="$VARIABLE_NAME" \
  -v value="$hls_url" '
    BEGIN {
      found = 0
    }

    index($0, key "=") == 1 {
      print key "=" value
      found = 1
      next
    }

    {
      print
    }

    END {
      if (!found) {
        print key "=" value
      }
    }
  ' "$ENV_FILE" > "$TEMPORARY_FILE"

chmod --reference="$ENV_FILE" "$TEMPORARY_FILE" 2>/dev/null || chmod 600 "$TEMPORARY_FILE"
mv "$TEMPORARY_FILE" "$ENV_FILE"
TEMPORARY_FILE=""

echo "Пересоздаю контейнер go2rtc..."

docker compose up -d --force-recreate go2rtc

echo "Готово: ссылка DSI обновлена, go2rtc перезапущен"