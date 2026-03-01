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

## Cloud Build (Jira + TestRail) sin `--source`

Para repos con múltiples entrypoints HTTP, usa imágenes dedicadas por servicio y despliegue con `--image`.

Este repo incluye: `simple/cloudbuild-jira-testrail.yaml`.

Qué hace:
- Construye imagen Jira con `--build-arg SOURCE_FILE=ingest-jira.py`.
- Construye imagen TestRail con `--build-arg SOURCE_FILE=ingest-testrail.py`.
- Despliega cada servicio con su imagen propia (`gcloud run deploy ... --image=...`).
- Fuerza `functions-framework --source` correcto por servicio en Cloud Run.
- Valida con POST autenticado y falla si en logs recientes aparece `/app/main.py` o `BUGSNAG_BASE_URL`.

Ejemplo de ejecución:

```bash
gcloud builds submit --config simple/cloudbuild-jira-testrail.yaml .
```
