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

### Testrail quick-fix runbook (BQ dataset/location mismatch)

Para incidentes en `testrail-ingest-function` con `BQ_DATASET_NOT_FOUND_ALERT`, usa este script:

```bash
simple/scripts/fix_testrail_bq_config.sh
```

El script ejecuta en orden:

1. Inspección de env vars efectivas en Cloud Run: `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION`.
2. Verificación del dataset real vía `bq show --format=prettyjson <PROJECT>:<DATASET>` y lectura de `.location`.
3. Alineación automática de valores finales de `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION`.
4. Re-deploy de `testrail-ingest-function` conservando `--source=testrail/main.py`.
5. Validación en logs: desaparición de `BQ_DATASET_NOT_FOUND_ALERT` y retorno de invocaciones `POST 200`.

Overrides útiles:

```bash
PROJECT_ID=qa-panda-metrics \
REGION=europe-west1 \
TARGET_BQ_PROJECT=qa-panda-metrics \
TARGET_BQ_DATASET=qa_metrics_simple \
TARGET_BQ_LOCATION=EU \
simple/scripts/fix_testrail_bq_config.sh
```
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

En los ingests de `/simple`, el fallback de BigQuery ya es **automático** cuando la operación
falla por dataset no encontrado o mismatch de región (ej: `Dataset ... was not found in location ...`).

- Dataset primario: `BQ_DATASET` (default: `qa_metrics_simple`).
- Dataset fallback: `BQ_DATASET_FALLBACK`.
  - Si no defines `BQ_DATASET_FALLBACK`, se usa automáticamente `<BQ_DATASET>_mirror`
    (por ejemplo `qa_metrics_simple_mirror`).
  - Para desactivar fallback, define `BQ_DATASET_FALLBACK` en vacío (`""`).

Si primario y fallback fallan, la request falla reportando ambos errores para facilitar diagnóstico.

Para observabilidad, se emite evento estructurado adicional cuando se usa fallback:

- `BQ_DATASET_FALLBACK_USED operation=<query|insert> project=<...> primary_dataset=<...> fallback_dataset=<...> location=<...> primary_error=<...>`

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
| `simple-dev` | `qa-panda-metrics-dev` | `qa_metrics_simple` | `US` (o ubicación real del dataset) | pruebas de integración |
| `simple-prod` | `qa-panda-metrics` | `qa_metrics_simple` | `US` (o ubicación real del dataset) | dashboard/explore principal |
| `simple-prod-fallback` | `qa-panda-metrics` | `qa_metrics_simple_mirror` | `US` (o ubicación real del dataset espejo) | continuidad operativa |

> Nota: el valor final de `BQ_LOCATION` debe coincidir exactamente con `bq show --format=prettyjson <PROJECT>:<DATASET> | jq -r '.location'`.

## Ingest services: required env var matrix

> Focus: servicios en `/simple`.

| Servicio | Env vars requeridas (alguna alternativa por grupo) | Env vars opcionales |
|---|---|---|
| `simple/bugsnag/main.py` | `BUGSNAG_BASE_URL`; `BUGSNAG_TOKEN`; `BUGSNAG_PROJECT_IDS` | `BUGSNAG_MAX_RUNTIME_S`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/jira/main.py` | `JIRA_SITE` \| `JIRA_BASE_URL`; `JIRA_USER` \| `JIRA_EMAIL`; `JIRA_API_TOKEN`; `JIRA_PROJECT_KEYS` \| `JIRA_PROJECT_KEYS_CSV` \| `JIRA_PROJECT_KEY` | `JIRA_SEVERITY_FIELD_ID` \| `JIRA_SEVERITY_FIELD`, `JIRA_POD_FIELD`, `JIRA_LOOKBACK_DAYS`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/testrail/main.py` | `TESTRAIL_BASE_URL` \| `TESTRAIL_URL`; `TESTRAIL_EMAIL` \| `TESTRAIL_USER` \| `TESTRAIL_USERNAME`; `TESTRAIL_API_KEY` \| `TESTRAIL_TOKEN` \| `TESTRAIL_API_TOKEN`; `TESTRAIL_PROJECT_IDS` \| `TESTRAIL_PROJECTS` \| `TESTRAIL_PROJECT_ID` \| `TESTRAIL_PROJECT` | `TESTRAIL_LOOKBACK_DAYS`, `TESTRAIL_BVT_SUITE_NAME`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/gamebench/main.py` | `GAMEBENCH_USER`; `GAMEBENCH_TOKEN` | `GAMEBENCH_COMPANY_ID`, `GAMEBENCH_COLLECTION_ID`, `GAMEBENCH_APP_PACKAGES`, `GAMEBENCH_LOOKBACK_DAYS`, `GAMEBENCH_AUTH_MODE`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |

## Build pipeline único (raíz del repo)

Para evitar drift, el pipeline oficial ahora es **solo** `cloudbuild.yaml` en la raíz del repositorio.

Comando oficial:

```bash
gcloud builds submit --config cloudbuild.yaml .
```

### Source of truth (substitutions por defecto)

El pipeline raíz publica los 4 servicios de `/simple` con:

- `--set-env-vars=BQ_PROJECT=${_BQ_PROJECT},BQ_DATASET=${_BQ_DATASET},BQ_LOCATION=${_BQ_LOCATION}`
- Región runtime: `_REGION=us-central1`
- BigQuery location: `_BQ_LOCATION=US`

Servicios + source esperado:

- `bugsnag-ingest-function` -> `bugsnag/main.py`
- `jira-ingest-function` -> `jira/main.py`
- `testrail-ingest-function` -> `testrail/main.py`
- `gamebench-ingest-function` -> `gamebench/main.py`

### Override recomendado por entorno

```bash
# DEV
gcloud builds submit --config cloudbuild.yaml   --substitutions=_BQ_PROJECT=qa-panda-metrics-dev,_BQ_DATASET=qa_metrics_simple,_BQ_LOCATION=US .

# PROD
gcloud builds submit --config cloudbuild.yaml   --substitutions=_BQ_PROJECT=qa-panda-metrics,_BQ_DATASET=qa_metrics_simple,_BQ_LOCATION=US .

# PROD fallback (mirror)
gcloud builds submit --config cloudbuild.yaml   --substitutions=_BQ_PROJECT=qa-panda-metrics,_BQ_DATASET=qa_metrics_simple_mirror,_BQ_LOCATION=US .
```
