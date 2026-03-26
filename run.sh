#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="x-trading-476913"
REGION="global"
IMAGE="gcr.io/$PROJECT_ID/podlodka-demo:latest"
CONTAINER="podlodka-demo"
BUILD_TRIGGER="${BUILD_TRIGGER:-podlodka-demo}"

echo "[1/4] Запускаю Cloud Build trigger '$BUILD_TRIGGER'..."

BUILD_ID=$(gcloud builds triggers run "$BUILD_TRIGGER" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(metadata.build.id)" 2>/dev/null)

if [ -z "$BUILD_ID" ]; then
  echo "Не удалось получить BUILD_ID. Проверь имя trigger и авторизацию gcloud."
  exit 1
fi

echo "[2/4] Ожидаю завершения билда $BUILD_ID..."
while true; do
  STATUS=$(gcloud builds describe "$BUILD_ID" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="value(status)" 2>/dev/null)
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
  sleep 10
done

echo "[3/4] Обновляю локальный контейнер '$CONTAINER'..."
docker stop "$CONTAINER" 2>/dev/null || true
docker rm "$CONTAINER" 2>/dev/null || true

echo "[4/4] Тяну и запускаю образ '$IMAGE'..."
docker pull "$IMAGE"
docker run -d --name "$CONTAINER" --restart unless-stopped "$IMAGE"

echo "DEPLOY_SUCCESS"
echo "Контейнер '$CONTAINER' запущен."
