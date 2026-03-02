#!/usr/bin/env bash
set -euo pipefail

PROJECT="qa-panda-metrics"
DATASET="qa_metrics_simple"
REGION="europe-west1"
SERVICE="gamebench-ingest-function"

if ! command -v bq >/dev/null 2>&1; then
  echo "ERROR: bq CLI no está disponible en PATH." >&2
  exit 127
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud CLI no está disponible en PATH." >&2
  exit 127
fi

echo "[1/5] Obteniendo ubicación real de dataset ${PROJECT}:${DATASET}..."
BQ_LOCATION="$(bq show --format=prettyjson "${PROJECT}:${DATASET}" | jq -r '.location')"
if [ -z "${BQ_LOCATION}" ] || [ "${BQ_LOCATION}" = "null" ]; then
  echo "ERROR: No se pudo resolver la ubicación del dataset." >&2
  exit 1
fi
printf 'Dataset location: %s\n' "${BQ_LOCATION}"

echo "[2/5] Variables actuales del servicio ${SERVICE}..."
gcloud run services describe "${SERVICE}" --region="${REGION}" \
  --format='yaml(spec.template.spec.containers[0].env)'

echo "[3/5] Actualizando env vars BQ_*..."
gcloud run services update "${SERVICE}" \
  --region="${REGION}" \
  --update-env-vars "BQ_PROJECT=${PROJECT},BQ_DATASET=${DATASET},BQ_LOCATION=${BQ_LOCATION}"

echo "[4/5] Invocación manual POST (dry_run)..."
TOKEN="$(gcloud auth print-identity-token)"
URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --format='value(status.url)')"
curl -iSsf -X POST "${URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true, "lookback_days": 1}'

echo
echo "[5/5] Validación en logs (dataset-not-found desaparece + POST 200)..."
SINCE="$(date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"

gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND timestamp>=\"${SINCE}\"" \
  --limit=200 \
  --format='value(timestamp,httpRequest.status,textPayload)'

echo
echo "Checklist esperado:"
echo "- No aparecen errores: Dataset ... was not found in location ..."
echo "- Existe al menos una línea con status 200 de la invocación POST"
