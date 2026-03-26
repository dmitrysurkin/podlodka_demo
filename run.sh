#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="x-trading-476913"
REGION="global"
IMAGE="gcr.io/$PROJECT_ID/helloWorld:latest"
CONTAINER="helloWorld"
BUILD_TRIGGER="${BUILD_TRIGGER:-helloWorld}"
POLL_INTERVAL_SEC="${POLL_INTERVAL_SEC:-10}"
BUILD_TIMEOUT_SEC="${BUILD_TIMEOUT_SEC:-1800}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Не найдена команда '$1'. Установи ее и попробуй снова." >&2
    exit 1
  fi
}

run_gcloud() {
  local output

  if ! output=$(gcloud "$@" 2>&1); then
    echo "Команда gcloud завершилась с ошибкой:" >&2
    echo "gcloud $*" >&2
    echo "$output" >&2
    exit 1
  fi

  printf '%s\n' "$output"
}

require_cmd gcloud
require_cmd docker

echo "PROJECT_ID=$PROJECT_ID"
echo "REGION=$REGION"
echo "BUILD_TRIGGER=$BUILD_TRIGGER"
echo "[1/4] Запускаю Cloud Build trigger '$BUILD_TRIGGER'..."

BUILD_ID=$(run_gcloud builds triggers run "$BUILD_TRIGGER" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(metadata.build.id)")

if [ -z "$BUILD_ID" ]; then
  echo "Не удалось получить BUILD_ID. Проверь имя trigger, регион и авторизацию gcloud."
  exit 1
fi

echo "[2/4] Ожидаю завершения билда $BUILD_ID..."
SECONDS_WAITED=0
while true; do
  STATUS=$(run_gcloud builds describe "$BUILD_ID" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="value(status)")
  echo "Статус: $STATUS"
  case "$STATUS" in
    SUCCESS)
      echo "Билд завершился успешно."
      break
      ;;
    FAILURE|CANCELLED|TIMEOUT|INTERNAL_ERROR|EXPIRED)
      echo "Билд завершился с ошибкой: $STATUS"
      exit 1
      ;;
  esac

  if [ "$SECONDS_WAITED" -ge "$BUILD_TIMEOUT_SEC" ]; then
    echo "Превышено время ожидания билда: ${BUILD_TIMEOUT_SEC}s"
    exit 1
  fi

  sleep "$POLL_INTERVAL_SEC"
  SECONDS_WAITED=$((SECONDS_WAITED + POLL_INTERVAL_SEC))
done

echo "[3/4] Обновляю локальный контейнер '$CONTAINER'..."
docker stop "$CONTAINER" 2>/dev/null || true
docker rm "$CONTAINER" 2>/dev/null || true

echo "[4/4] Тяну и запускаю образ '$IMAGE'..."
docker pull "$IMAGE"
docker run -d --name "$CONTAINER" --restart unless-stopped "$IMAGE"

echo "DEPLOY_SUCCESS"
echo "Контейнер '$CONTAINER' запущен."
