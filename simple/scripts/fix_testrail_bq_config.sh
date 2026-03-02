#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-testrail-ingest-function}"
REGION="${REGION:-europe-west1}"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "ERROR: PROJECT_ID is empty. Set PROJECT_ID or run 'gcloud config set project <id>'." >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud CLI is required." >&2
  exit 1
fi

if ! command -v bq >/dev/null 2>&1; then
  echo "ERROR: bq CLI is required (ships with Cloud SDK)." >&2
  exit 1
fi

since_ts="${LOGS_SINCE:-$(date -u -d '90 minutes ago' +%Y-%m-%dT%H:%M:%SZ)}"

echo "== 1) Effective Cloud Run env vars (${SERVICE_NAME}, region=${REGION}) =="
service_json="$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" --format=json)"

env_names=(BQ_PROJECT BQ_DATASET BQ_LOCATION)
for name in "${env_names[@]}"; do
  value="$(jq -r --arg k "$name" '.spec.template.spec.containers[0].env[]? | select(.name==$k) | .value' <<<"${service_json}" | tail -n1)"
  if [[ -z "${value}" || "${value}" == "null" ]]; then
    value="<unset>"
  fi
  printf '%s=%s\n' "$name" "$value"
done

current_bq_project="$(jq -r '.spec.template.spec.containers[0].env[]? | select(.name=="BQ_PROJECT") | .value' <<<"${service_json}" | tail -n1)"
current_bq_dataset="$(jq -r '.spec.template.spec.containers[0].env[]? | select(.name=="BQ_DATASET") | .value' <<<"${service_json}" | tail -n1)"
current_bq_location="$(jq -r '.spec.template.spec.containers[0].env[]? | select(.name=="BQ_LOCATION") | .value' <<<"${service_json}" | tail -n1)"

if [[ -z "${current_bq_project}" || "${current_bq_project}" == "null" ]]; then
  current_bq_project="${PROJECT_ID}"
fi
if [[ -z "${current_bq_dataset}" || "${current_bq_dataset}" == "null" ]]; then
  current_bq_dataset="qa_metrics_simple"
fi
if [[ -z "${current_bq_location}" || "${current_bq_location}" == "null" ]]; then
  current_bq_location="EU"
fi

target_bq_project="${TARGET_BQ_PROJECT:-$current_bq_project}"
target_bq_dataset="${TARGET_BQ_DATASET:-$current_bq_dataset}"

echo
echo "== 2) Verify dataset existence/location (${target_bq_project}:${target_bq_dataset}) =="
dataset_json="$(bq --project_id="${target_bq_project}" show --format=prettyjson "${target_bq_project}:${target_bq_dataset}")"
actual_dataset_location="$(jq -r '.location // empty' <<<"${dataset_json}")"

if [[ -z "${actual_dataset_location}" ]]; then
  echo "ERROR: Could not read dataset location from bq show output." >&2
  exit 1
fi

printf 'dataset.location=%s\n' "${actual_dataset_location}"

echo
echo "== 3) Resolve aligned runtime config =="
final_bq_project="${target_bq_project}"
final_bq_dataset="${target_bq_dataset}"
final_bq_location="${TARGET_BQ_LOCATION:-$actual_dataset_location}"

printf 'Final BQ_PROJECT=%s\n' "${final_bq_project}"
printf 'Final BQ_DATASET=%s\n' "${final_bq_dataset}"
printf 'Final BQ_LOCATION=%s\n' "${final_bq_location}"

source_arg='-c,functions-framework --target=hello_http --source=testrail/main.py --port=${PORT}'

echo
echo "== 4) Re-deploy service with explicit source and aligned BQ env =="
gcloud run deploy "${SERVICE_NAME}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --platform managed \
  --source . \
  --entry-point hello_http \
  --set-env-vars "BQ_PROJECT=${final_bq_project},BQ_DATASET=${final_bq_dataset},BQ_LOCATION=${final_bq_location}" \
  --args "${source_arg}" \
  --quiet

echo
echo "== 5) Validate logs: no BQ_DATASET_NOT_FOUND_ALERT and POST 200 restored =="
alert_count="$(gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME} AND textPayload:BQ_DATASET_NOT_FOUND_ALERT AND timestamp>=\"${since_ts}\"" \
  --project "${PROJECT_ID}" \
  --limit 20 --format='value(timestamp)' | wc -l | tr -d ' ')"

post_200_count="$(gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME} AND httpRequest.requestMethod=\"POST\" AND httpRequest.status=200 AND timestamp>=\"${since_ts}\"" \
  --project "${PROJECT_ID}" \
  --limit 50 --format='value(timestamp)' | wc -l | tr -d ' ')"

echo "BQ_DATASET_NOT_FOUND_ALERT_count=${alert_count}"
echo "POST_200_count=${post_200_count}"

if [[ "${alert_count}" != "0" ]]; then
  echo "WARNING: Alert is still appearing. Re-check PROJECT/DATASET/LOCATION values." >&2
fi

if [[ "${post_200_count}" == "0" ]]; then
  echo "WARNING: No POST 200 found yet in the selected log window (${since_ts}..now)." >&2
fi

echo "Done."
