# Simple pipelines

## GameBench defaults (Panda)

El pipeline `simple/gamebench/main.py` soporta defaults para Panda y permite override vía variables de entorno:

- `GAMEBENCH_COMPANY_ID` (default: `AWGaWNjXBxsUazsJuoUp`)
- `GAMEBENCH_COLLECTION_ID` (default: `7cf80f11-6915-4e6c-b70c-4ad7ed44aaf9`)
- `GAMEBENCH_APP_PACKAGES` (default CSV):
  - `com.scopely.internal.wwedomination`
  - `com.scopely.wwedomination`

Si defines estas variables de entorno en despliegue, prevalecen sobre los defaults.

Además, la búsqueda en GameBench separa filtros por `package` y `environment` para mantener la lógica `dev/prod`:

- Paquetes con `.internal.` (o sufijo `.internal`) => `environment=dev`
- Resto => `environment=prod`

## BigQuery location (important)

If your dataset `qa_metrics_simple` is in **EU**, set (or keep) this env var in each simple service:

- `BQ_LOCATION=EU`

If your dataset is in another region (for example `US`), set `BQ_LOCATION` accordingly.
Without this, queries can fail with errors like: `Dataset ... was not found in location US`.

Typical mismatch example:

- Dataset physically located in `europe-west1`.
- Service configured with `BQ_LOCATION=EU` or `BQ_LOCATION=US`.

Recommended verification command:

```bash
bq show --format=prettyjson <PROJECT_ID>:qa_metrics_simple | jq -r '.location'
```

Use that exact location value for `BQ_LOCATION` in each service.

### Quick fix for `gamebench-ingest-function`

If you need to align env vars exactly with the real dataset location and validate end-to-end (`POST 200` + logs), run:

```bash
bash simple/scripts/align_gamebench_bq_env.sh
```

This script performs the same operational flow requested for incident response:
1. Reads dataset location with `bq show ... | jq -r .location`.
2. Prints current Cloud Run env vars.
3. Updates `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION`.
4. Executes authenticated manual `POST` (`dry_run`).
5. Prints recent logs to confirm dataset-location errors are gone and request status returns `200`.

## Dashboard/Explore fallback and incident mapping (`/simple`)

### 1) Element identification in Looker (`77c0972751e263ff96782c74cc0a25c8`)

- Este id corresponde a un **runtime/UI element id** de Looker (no se versiona dentro de los archivos LookML).
- Referencia operativa del dashboard: `simple/looker/qa_executive.dashboard` (`dashboard: qa_executive`, explore `qa_executive_kpis`).
- Si necesitas el mapeo exacto id -> tile en caliente, usa Looker API sobre el dashboard desplegado (query de elementos y matching por `id`).

### 2) Fallback behavior (friendly + stable mirror)

Cuando falle la fuente primaria por dataset/región (ej: `Dataset ... was not found in location ...`):

1. Mostrar mensaje amigable: **"Data not available right now"**.
2. Cambiar temporalmente el origen del explore a la tabla espejo estable:
   - `qa-panda-metrics.qa_metrics_simple_mirror.qa_executive_kpis_latest`
3. Abrir incidente de configuración y validar `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION`.

### 3) Monitoring/alerting for dataset-not-found regressions

Los ingests en `/simple` emiten un log estructurado en error cuando detectan dataset no encontrado o mismatch de región:

- `BQ_DATASET_NOT_FOUND_ALERT project=<...> dataset=<...> location=<...> error=<...>`

Recomendación de alerta en Cloud Monitoring:

- Tipo: **log-based metric** (counter).
- Filtro:

```text
resource.type="cloud_run_revision"
textPayload:"BQ_DATASET_NOT_FOUND_ALERT"
```

- Condición sugerida: `count >= 1` en ventana de 5 minutos por servicio.
- Notificación: Slack/on-call de Data QA.

### 4) Mapping esperado entorno -> proyecto -> dataset -> región

| Entorno | Proyecto GCP (`BQ_PROJECT`) | Dataset (`BQ_DATASET`) | Región (`BQ_LOCATION`) | Uso |
|---|---|---|---|---|
| `simple-dev` | `qa-panda-metrics-dev` | `qa_metrics_simple` | `EU` (o ubicación real del dataset) | pruebas de integración |
| `simple-prod` | `qa-panda-metrics` | `qa_metrics_simple` | `EU` (o ubicación real del dataset) | dashboard/explore principal |
| `simple-prod-fallback` | `qa-panda-metrics` | `qa_metrics_simple_mirror` | `EU` (o ubicación real del dataset espejo) | continuidad operativa |

> Nota: el valor final de `BQ_LOCATION` debe coincidir exactamente con `bq show --format=prettyjson <PROJECT>:<DATASET> | jq -r '.location'`.

## Ingest services: required env var matrix

> Focus: servicios en `/simple`.

| Servicio | Env vars requeridas (alguna alternativa por grupo) | Env vars opcionales |
|---|---|---|
| `simple/bugsnag/main.py` | `BUGSNAG_BASE_URL`; `BUGSNAG_TOKEN`; `BUGSNAG_PROJECT_IDS` | `BUGSNAG_MAX_RUNTIME_S`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/jira/main.py` | `JIRA_SITE` \| `JIRA_BASE_URL`; `JIRA_USER` \| `JIRA_EMAIL`; `JIRA_API_TOKEN`; `JIRA_PROJECT_KEYS` \| `JIRA_PROJECT_KEYS_CSV` \| `JIRA_PROJECT_KEY` | `JIRA_SEVERITY_FIELD_ID` \| `JIRA_SEVERITY_FIELD`, `JIRA_POD_FIELD`, `JIRA_LOOKBACK_DAYS`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/testrail/main.py` | `TESTRAIL_BASE_URL` \| `TESTRAIL_URL`; `TESTRAIL_EMAIL` \| `TESTRAIL_USER` \| `TESTRAIL_USERNAME`; `TESTRAIL_API_KEY` \| `TESTRAIL_TOKEN` \| `TESTRAIL_API_TOKEN`; `TESTRAIL_PROJECT_IDS` \| `TESTRAIL_PROJECTS` \| `TESTRAIL_PROJECT_ID` \| `TESTRAIL_PROJECT` | `TESTRAIL_LOOKBACK_DAYS`, `TESTRAIL_BVT_SUITE_NAME`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/gamebench/main.py` | `GAMEBENCH_USER`; `GAMEBENCH_TOKEN` | `GAMEBENCH_COMPANY_ID`, `GAMEBENCH_COLLECTION_ID`, `GAMEBENCH_APP_PACKAGES`, `GAMEBENCH_LOOKBACK_DAYS`, `GAMEBENCH_AUTH_MODE`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |

## Build pipelines existentes y cobertura

Archivos de Cloud Build existentes en `/simple`:

| Pipeline | Cobertura real |
|---|---|
| `simple/cloudbuild-jira-testrail.yaml` | Solo despliega `jira-ingest-function` (`jira/main.py`) y `testrail-ingest-function` (`testrail/main.py`). |
| `simple/cloudbuild-all-simple.yaml` | Despliega los 4 servicios: `bugsnag`, `jira`, `testrail`, `gamebench`. |

Ejecución:

```bash
gcloud builds submit --config simple/cloudbuild-jira-testrail.yaml .
gcloud builds submit --config simple/cloudbuild-all-simple.yaml .
```

## Source of truth: mapping de BigQuery por entorno (Cloud Build substitutions)

Los pipelines de `/simple` (`cloudbuild-simple.yaml`, `cloudbuild-jira-testrail.yaml`, `cloudbuild-all-simple.yaml`) publican los servicios con:

- `--set-env-vars=BQ_PROJECT=${_BQ_PROJECT},BQ_DATASET=${_BQ_DATASET},BQ_LOCATION=${_BQ_LOCATION}`

Substitutions oficiales por entorno:

| Entorno | `_BQ_PROJECT` | `_BQ_DATASET` | `_BQ_LOCATION` |
|---|---|---|---|
| `simple-dev` | `qa-panda-metrics-dev` | `qa_metrics_simple` | `EU` |
| `simple-prod` | `qa-panda-metrics` | `qa_metrics_simple` | `EU` |
| `simple-prod-fallback` | `qa-panda-metrics` | `qa_metrics_simple_mirror` | `EU` |

Comandos de referencia (sin editar YAML):

```bash
# DEV
gcloud builds submit --config simple/cloudbuild-simple.yaml \
  --substitutions=_BQ_PROJECT=qa-panda-metrics-dev,_BQ_DATASET=qa_metrics_simple,_BQ_LOCATION=EU .

# PROD
gcloud builds submit --config simple/cloudbuild-simple.yaml \
  --substitutions=_BQ_PROJECT=qa-panda-metrics,_BQ_DATASET=qa_metrics_simple,_BQ_LOCATION=EU .

# PROD fallback (mirror)
gcloud builds submit --config simple/cloudbuild-simple.yaml \
  --substitutions=_BQ_PROJECT=qa-panda-metrics,_BQ_DATASET=qa_metrics_simple_mirror,_BQ_LOCATION=EU .
```

## Tabla operativa: servicio -> pipeline -> source esperado

| Servicio Cloud Run | Pipeline recomendado | `--source` esperado |
|---|---|---|
| `bugsnag-ingest-function` | `simple/cloudbuild-all-simple.yaml` | `bugsnag/main.py` |
| `jira-ingest-function` | `simple/cloudbuild-jira-testrail.yaml` o `simple/cloudbuild-all-simple.yaml` | `jira/main.py` |
| `testrail-ingest-function` | `simple/cloudbuild-jira-testrail.yaml` o `simple/cloudbuild-all-simple.yaml` | `testrail/main.py` |
| `gamebench-ingest-function` | `simple/cloudbuild-all-simple.yaml` | `gamebench/main.py` |

## Verificación post-deploy (por servicio)

Asume `REGION=europe-west1`.

### 1) Runtime args/source

```bash
REGION=europe-west1
for SVC in bugsnag-ingest-function jira-ingest-function testrail-ingest-function gamebench-ingest-function; do
  echo "=== $SVC runtime args ==="
  gcloud run services describe "$SVC" --region "$REGION" \
    --format="value(spec.template.spec.containers[0].args)"
done
```
Si hay drift de nombres, mantener aliases en código y normalizar despliegues. Ejemplo típico ya cubierto: `JIRA_SEVERITY_FIELD` vs `JIRA_SEVERITY_FIELD_ID`.
## Flujo único de deploy en `/simple` (4 servicios)

Comando oficial:

```bash
gcloud builds submit --config simple/cloudbuild-simple.yaml .
```

Naming oficial de servicios Cloud Run (1 imagen por servicio):

- `bugsnag-ingest-function`
- `jira-ingest-function`
- `testrail-ingest-function`
- `gamebench-ingest-function`

Validaciones obligatorias del pipeline (`simple/cloudbuild-simple.yaml`):

- Build por servicio usando **solo** `simple/Dockerfile` + `--build-arg SIMPLE_FUNCTION=<service-name>`.
- Tag inmutable por imagen: `:$SHORT_SHA` (sin promover `latest` en este flujo).
- Deploy de cada servicio con **su propia imagen** (`gcloud run deploy ... --image=<service>:$SHORT_SHA`).
- Verificación post-deploy por servicio:
  - `spec.template.spec.containers[0].args` contiene `<source>/main.py`, o
  - logs de arranque contienen `Using source: <source>/main.py`.
- Guardrail anti-mix de sources: el deploy falla si logs recientes contienen referencias a otro source (por ejemplo `BUGSNAG_BASE_URL` fuera de Bugsnag, `/app/main.py` genérico, o `<otro-servicio>/main.py`).

Validar que cada servicio incluya su `--source` correcto:
- bugsnag: `--source=bugsnag/main.py`
- jira: `--source=jira/main.py`
- testrail: `--source=testrail/main.py`
- gamebench: `--source=gamebench/main.py`

### 2) Variable mínima requerida (presencia en env)

```bash
REGION=europe-west1

# bugsnag
gcloud run services describe bugsnag-ingest-function --region "$REGION" \
  --format="value(spec.template.spec.containers[0].env[].name)" | tr ';' '\n' | grep -E '^BUGSNAG_BASE_URL$'

# jira
gcloud run services describe jira-ingest-function --region "$REGION" \
  --format="value(spec.template.spec.containers[0].env[].name)" | tr ';' '\n' | grep -E '^(JIRA_SITE|JIRA_BASE_URL)$'

# testrail
gcloud run services describe testrail-ingest-function --region "$REGION" \
  --format="value(spec.template.spec.containers[0].env[].name)" | tr ';' '\n' | grep -E '^(TESTRAIL_BASE_URL|TESTRAIL_URL)$'

# gamebench
gcloud run services describe gamebench-ingest-function --region "$REGION" \
  --format="value(spec.template.spec.containers[0].env[].name)" | tr ';' '\n' | grep -E '^GAMEBENCH_USER$'
```

### 3) Smoke POST autenticado (uno por servicio)

```bash
REGION=europe-west1
TOKEN="$(gcloud auth print-identity-token)"

# bugsnag
BUGSNAG_URL="$(gcloud run services describe bugsnag-ingest-function --region "$REGION" --format='value(status.url)')"
curl -fsS -X POST "$BUGSNAG_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true, "hours": 1}'

# jira
JIRA_URL="$(gcloud run services describe jira-ingest-function --region "$REGION" --format='value(status.url)')"
curl -fsS -X POST "$JIRA_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true, "lookback_days": 1}'

# testrail
TESTRAIL_URL="$(gcloud run services describe testrail-ingest-function --region "$REGION" --format='value(status.url)')"
curl -fsS -X POST "$TESTRAIL_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true, "days": 1}'

# gamebench
GAMEBENCH_URL="$(gcloud run services describe gamebench-ingest-function --region "$REGION" --format='value(status.url)')"
curl -fsS -X POST "$GAMEBENCH_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true, "lookback_days": 1}'
```
