#!/usr/bin/env bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:${PATH:-}"

PROJECT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" &&
  pwd
)"

ENV_FILE="$PROJECT_DIR/.env"
SECRET_FILE="$PROJECT_DIR/.dsi.env"
LOCK_DIR="$PROJECT_DIR/.refresh-dsi.lock"

# Формат: camera_id|переменная_в_env|referer
CAMERAS=(
  "18894|DSI_173481138_URL|https://video.dsi.ru/account/camera/18894/view.html?backPage=5"
  "18882|DSI_173547486_URL|https://video.dsi.ru/account/view.html?page=4"
  "18902|DSI_173588244_URL|https://video.dsi.ru/account/view.html?page=6"
  "18918|DSI_173588440_URL|https://video.dsi.ru/account/view.html?page=8"
  "20108|DSI_173588496_URL|https://video.dsi.ru/account/view.html?page=9"
  "21752|DSI_173588798_URL|https://video.dsi.ru/account/view.html?page=17"
  "21744|DSI_173588876_URL|https://video.dsi.ru/account/view.html?page=16"
)

TEMPORARY_FILE=""
CURL_HLS_TLS_ARGS=()

# DSI использует устаревший короткий DH-ключ. Linux curl с OpenSSL
# требует SECLEVEL=1. Системный curl macOS этот синтаксис не поддерживает.
if [[ "$(uname -s)" == "Linux" ]]; then
  CURL_HLS_TLS_ARGS=(
    --tls-max 1.2
    --ciphers 'DEFAULT:@SECLEVEL=1'
  )
fi

cleanup() {
  if [[ -n "$TEMPORARY_FILE" && -f "$TEMPORARY_FILE" ]]; then
    rm -f "$TEMPORARY_FILE"
  fi

  if [[ -d "$LOCK_DIR" ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cd "$PROJECT_DIR"

if [[ -d "$LOCK_DIR" ]]; then
  echo "Обновление уже выполняется или осталась старая блокировка:"
  echo "$LOCK_DIR"
  exit 0
fi

if ! mkdir "$LOCK_DIR"; then
  echo "Не удалось создать блокировку: $LOCK_DIR"
  echo "Проверь владельца и права папки: $PROJECT_DIR"
  exit 1
fi

for command_name in curl jq awk sed grep docker uname; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Не найдена команда: $command_name"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "Не найден Docker Compose"
  exit 1
fi

if [[ ! -f "$SECRET_FILE" ]]; then
  echo "Не найден файл с cookie: $SECRET_FILE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Не найден файл: $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$SECRET_FILE"

if [[ -z "${DSI_COOKIE:-}" ]]; then
  echo "Переменная DSI_COOKIE отсутствует в $SECRET_FILE"
  exit 1
fi

VARIABLE_NAMES=()
HLS_URLS=()

get_hls_url() {
  local camera_id="$1"
  local referer="$2"
  local cache_buster
  local response
  local rtsp_url
  local hls_url
  local playlist

  cache_buster="$(date +%s)000"

  response="$(
    curl --fail --silent --show-error \
      --get \
      --url "https://video.dsi.ru/account/camera/${camera_id}/url.html" \
      --data-urlencode 'time=' \
      --data-urlencode 'timeZoneOffset=10800' \
      --data-urlencode 'format=hls' \
      --data-urlencode "_=${cache_buster}" \
      -H 'Accept: application/json, text/javascript, */*; q=0.01' \
      -H "Referer: ${referer}" \
      -H 'User-Agent: Mozilla/5.0' \
      -H 'X-Requested-With: XMLHttpRequest' \
      -b "$DSI_COOKIE"
  )"

  if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    echo "Камера ${camera_id}: сервер вернул не JSON" >&2
    return 1
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
    echo "Камера ${camera_id}: получен адрес неожиданного формата" >&2
    return 1
  fi

  playlist="$(
    curl --fail --silent --show-error --http1.1 \
      "${CURL_HLS_TLS_ARGS[@]}" \
      --url "$hls_url" \
      -H 'Accept: */*' \
      -H 'Origin: https://video.dsi.ru' \
      -H 'Referer: https://video.dsi.ru/' \
      -H 'User-Agent: Mozilla/5.0'
  )"

  if ! printf '%s\n' "$playlist" | grep -q '^#EXTM3U'; then
    echo "Камера ${camera_id}: получен некорректный HLS-плейлист" >&2
    return 1
  fi

  printf '%s' "$hls_url"
}

update_env_variable() {
  local variable_name="$1"
  local variable_value="$2"

  TEMPORARY_FILE="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"

  awk \
    -v key="$variable_name" \
    -v value="$variable_value" '
      BEGIN { found = 0 }

      index($0, key "=") == 1 {
        print key "=" value
        found = 1
        next
      }

      { print }

      END {
        if (!found) {
          print key "=" value
        }
      }
    ' "$ENV_FILE" > "$TEMPORARY_FILE"

  chmod 600 "$TEMPORARY_FILE"
  mv "$TEMPORARY_FILE" "$ENV_FILE"
  TEMPORARY_FILE=""
}

echo "Получаю свежие ссылки для ${#CAMERAS[@]} камер..."

# Сначала получаем и проверяем все ссылки. Если одна проверка завершится
# ошибкой, .env останется без изменений.
for camera_config in "${CAMERAS[@]}"; do
  IFS='|' read -r camera_id variable_name referer <<< "$camera_config"

  echo "Проверяю камеру ${camera_id}..."
  hls_url="$(get_hls_url "$camera_id" "$referer")"

  VARIABLE_NAMES+=("$variable_name")
  HLS_URLS+=("$hls_url")
  echo "Камера ${camera_id}: ссылка получена и проверена"
done

changed=0

for ((index = 0; index < ${#VARIABLE_NAMES[@]}; index++)); do
  variable_name="${VARIABLE_NAMES[$index]}"
  hls_url="${HLS_URLS[$index]}"

  current_url="$(
    sed -n "s/^${variable_name}=//p" "$ENV_FILE" |
      head -n 1
  )"

  if [[ "$current_url" == "$hls_url" ]]; then
    echo "${variable_name}: ссылка не изменилась"
    continue
  fi

  echo "${variable_name}: обновляю ссылку"
  update_env_variable "$variable_name" "$hls_url"
  changed=1
done

if [[ "$changed" -eq 0 ]]; then
  echo "Все ссылки актуальны — перезапуск не требуется"
  exit 0
fi

echo "Пересоздаю контейнер go2rtc..."
docker compose up -d --force-recreate go2rtc
echo "Готово: ссылки обновлены, go2rtc перезапущен"
