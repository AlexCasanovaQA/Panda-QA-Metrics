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

## Ingest services: required env var matrix

> Focus: servicios en `/simple`.

| Servicio | Env vars requeridas (alguna alternativa por grupo) | Env vars opcionales |
|---|---|---|
| `simple/jira/main.py` | `JIRA_SITE` \| `JIRA_BASE_URL`; `JIRA_USER` \| `JIRA_EMAIL`; `JIRA_API_TOKEN`; `JIRA_PROJECT_KEYS` \| `JIRA_PROJECT_KEYS_CSV` \| `JIRA_PROJECT_KEY` | `JIRA_SEVERITY_FIELD_ID` \| `JIRA_SEVERITY_FIELD` (se soportan ambos nombres), `JIRA_POD_FIELD`, `JIRA_LOOKBACK_DAYS`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/testrail/main.py` | `TESTRAIL_BASE_URL` \| `TESTRAIL_URL`; `TESTRAIL_EMAIL` \| `TESTRAIL_USER` \| `TESTRAIL_USERNAME`; `TESTRAIL_API_KEY` \| `TESTRAIL_TOKEN` \| `TESTRAIL_API_TOKEN`; `TESTRAIL_PROJECT_IDS` \| `TESTRAIL_PROJECTS` \| `TESTRAIL_PROJECT_ID` \| `TESTRAIL_PROJECT` | `TESTRAIL_LOOKBACK_DAYS`, `TESTRAIL_BVT_SUITE_NAME`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |
| `simple/bugsnag/main.py` | `BUGSNAG_BASE_URL`; `BUGSNAG_TOKEN`; `BUGSNAG_PROJECT_IDS` | `BUGSNAG_MAX_RUNTIME_S`, `BQ_PROJECT`, `BQ_DATASET`, `BQ_LOCATION` |

### Verificación en Cloud Run (recomendada en cada deploy)

Comparar la matriz anterior contra la configuración real de cada servicio:

```bash
gcloud run services describe <service-name> \
  --region <region> \
  --format yaml(spec.template.spec.containers)
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

## Dockerfile simple: selección de `main.py` segura

`simple/Dockerfile` ahora soporta selección de entrypoint en runtime:

- Primero usa `SIMPLE_FUNCTION` (si se define explícitamente).
- Si no existe, usa `K_SERVICE` (Cloud Run) para elegir entre `bugsnag|jira|testrail|gamebench`.
- Si no puede resolver servicio, falla con error claro.

Esto evita casos donde un deploy de `gamebench-ingest-function` arranca por accidente con `bugsnag/main.py`
y falla por variables como `BUGSNAG_BASE_URL`.
