# Panda QA Metrics (Jira + TestRail + Bugsnag) -> BigQuery -> Looker

This repo is **ready to copy/paste into an empty GitHub repository**.

It contains:
- Ingestion services (Python + Functions Framework) that load **Jira**, **Jira changelog**, **TestRail**, **TestRail results**, and **Bugsnag** into **BigQuery**
- BigQuery setup SQL to create required tables/views
- A complete LookML project (model + views + dashboards) with **public vs private KPI access control**

Timezone: **UTC**

---

## 1) Required Secrets (GCP Secret Manager)

Create these secrets in the same GCP project where BigQuery lives (names must match exactly):

### Jira
- `JIRA_BASE_URL` **or** `JIRA_SITE` (e.g. `https://yourcompany.atlassian.net`)
- `JIRA_EMAIL` **or** `JIRA_USER` (email)
- `JIRA_API_TOKEN`
- `JIRA_SEVERITY_FIELD_ID` (**required for production**, e.g. `customfield_12345`)
  - In non-production, autodetection is still attempted, but a strong warning is logged and ingest exports severity-null counters.
  - In production (`ENVIRONMENT`/`APP_ENV`/`DEPLOY_ENV` = `prod` or `production`), missing this variable fails fast.

### TestRail
- `TESTRAIL_BASE_URL` (e.g. `https://testrail.yourcompany.com`)
- `TESTRAIL_USER` (or `TESTRAIL_EMAIL` for `ingest-testrail-users`)
- `TESTRAIL_API_KEY`
- `TESTRAIL_PROJECT_ID` (single id) **or** `TESTRAIL_PROJECT_IDS` (comma-separated)

### Bugsnag
- `BUGSNAG_BASE_URL` (e.g. `https://api.bugsnag.com`)
- `BUGSNAG_TOKEN`
- `BUGSNAG_PROJECT_IDS` (comma-separated)

---

## 2) BigQuery Setup

Run:

- `bigquery/setup.sql`

This will create:
- Dataset: `qa_metrics`
- Raw tables created automatically by ingestion (streaming inserts):
  - `jira_issues`
  - `jira_changelog`
  - `testrail_runs`
  - `testrail_results`
  - `bugsnag_errors`
- Helper views:
  - `jira_issues_latest`
  - `testrail_runs_latest`
  - `bugsnag_errors_latest`
  - `jira_status_changes`
- Catalog view:
  - `kpi_catalog`
- **Main KPI fact view used by Looker:**
  - `qa_kpi_facts`
- Additional LookML helper objects used directly by dashboards/views:
  - `jira_bug_events_daily`
  - `jira_fix_fail_rate_daily`
  - `jira_mttr_fixed_daily`
  - `jira_active_bug_count_daily`
  - `testrail_bvt_latest`
  - `build_size_manual` (table)
  - `gamebench_daily_metrics` (table)

### Manual KPI inputs
Some KPIs cannot be derived from Jira/TestRail/Bugsnag without more source data. They are supported via:
- `qa_metrics.manual_kpi_values`

Template inserts:
- `bigquery/manual_kpi_inserts_template.sql`
- `bigquery/build_size_manual_inserts_template.sql`

**Manual Public KPIs:** P27, P28, P29, P30, P35, P36, P37, P38, P40, P41, P42  
**Manual Private KPIs:** R1, R10, R17, R18, R19, R2, R20, R24, R3, R4, R5

### Build size (manual, operational MVP)
Use `qa_metrics.build_size_manual` as a manual weekly feed for the build-size tiles.

Recommended operating model:
- Insert/update at least one row per week per `(platform, environment)`.
- Required fields: `platform`, `environment`, `build_version`, `build_size_mb`, `metric_date` (UTC date).
- Use `bigquery/build_size_manual_inserts_template.sql` as the starter template.

Validation expectation:
- After inserting at least 2-4 rows reales (for example across two weeks and two platforms), Build Size tiles should stop showing `No results`.

### Runbook (carga institucionalizada mínima) — Build Size manual
1. **Preparar datos semanales** (UTC): recopilar `platform`, `environment`, `build_version`, `build_size_mb`, `metric_date`.
2. **Ejecutar carga** usando `bigquery/build_size_manual_inserts_template.sql` (reemplazar valores de ejemplo por datos reales).
3. **Validar en BigQuery**:
   - Confirmar que existen al menos **2-4 filas reales** recientes en `qa_metrics.build_size_manual`.
   - Recomendado: validar con una consulta de conteo de últimos 30 días (incluida como bloque comentado en el template SQL).
4. **Validar en Looker (qa_executive)**:
   - Tile **snapshot** (`current_build_size_by_platform`) **ignora Date Range** por diseño.
   - Tile **trend** (`build_size_mb_trend`) **escucha Date Range** por diseño.
   - Resultado esperado: desaparece el estado `No results` en Build Size.
5. **Operación continua**: mantener una frecuencia mínima de 1 carga por semana y plataforma/entorno.

---

## Refresh strategy for helper views/tables (avoid empty dashboard tiles)

Some Looker tiles read from pre-aggregated helper objects. To keep them populated, run a **daily Scheduled Query** (or a materialization job) that executes the relevant statements from `bigquery/setup.sql`:

- `CREATE OR REPLACE VIEW qa_metrics.jira_bug_events_daily`
- `CREATE OR REPLACE VIEW qa_metrics.jira_fix_fail_rate_daily`
- `CREATE OR REPLACE VIEW qa_metrics.jira_mttr_fixed_daily`
- `CREATE OR REPLACE VIEW qa_metrics.jira_active_bug_count_daily`
- `CREATE OR REPLACE VIEW qa_metrics.testrail_bvt_latest`

Recommended frequency:
- At least once per day (UTC), **after** Jira/TestRail ingestion finishes.
- Optional: every 4-6 hours for fresher operational dashboards.

For manual/source-fed tables, ensure an equivalent daily load process exists:
- `qa_metrics.build_size_manual`
- `qa_metrics.gamebench_daily_metrics`

### Gamebench daily aggregate refresh
Use `bigquery/gamebench_daily_refresh.sql` to upsert daily Gamebench aggregates into `qa_metrics.gamebench_daily_metrics`.

Recommended frequency:
- At least once per day (UTC), preferably right after `ingest-gamebench` completes.
- Optional: every 4-6 hours if you need fresher performance telemetry tiles.

Orchestration options:
- **Workflow-integrated (included):** `workflows/qa_metrics_ingestion.yaml` now runs the BigQuery `MERGE` as a `gamebench_daily_refresh` step after Android/iOS ingestion calls.
- **Scheduled Query + Cloud Scheduler:** create a BigQuery Scheduled Query that executes `bigquery/gamebench_daily_refresh.sql`, then trigger it after your ingestion workflow.

If these refreshes are skipped, Looker explores can compile correctly but charts may render with no rows.

### Data quality rules (Gamebench dashboard sources)
Post-ingestion quality checks are enforced in `workflows/qa_metrics_ingestion.yaml` immediately after `gamebench_daily_refresh` to guard against empty/stale data in dashboard source tables.

SLA and validation windows (**UTC**):
- `qa_metrics.gamebench_sessions_latest` must have `row_count > 0` in the **last 24 hours** (`time_pushed >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)`).
- `qa_metrics.gamebench_daily_metrics` must have `row_count > 0` in the **last 2 days** (`metric_date >= DATE_SUB(CURRENT_DATE("UTC"), INTERVAL 2 DAY)`).
- `qa_metrics.build_size_manual` is checked as an operational warning for emptiness in the **last 30 days** (`metric_date >= DATE_SUB(CURRENT_DATE("UTC"), INTERVAL 30 DAY)`) to alert if manual feed is missing.

Workflow behavior on check failure:
- Returns non-OK workflow output (`status: non_ok`, `dq_status: non_ok`).
- Emits structured log entry with `dataset`, `table`, `checked_window`, and `row_count` for each check (for Cloud Logging metrics/alerts).
- Optionally posts an alert webhook when `dq_alert_webhook_url` is supplied in workflow args.

## 3) Field Mapping (per your requirements)

The system maps Jira fields into KPI dimensions like this:
- **POD** = Jira **Team** field (handled via `customfield_10001` and stored in `team`)
- **feature** = Jira **component**
- **release** = Jira **fixVersion**
- **sprint** = Jira **sprint** (parsed from Jira sprint string)

Jira statuses handled explicitly:
- `Open / Backlog / In Progress / Ready for QA / Closed / Verified / Resolved / In Review / In QA / Blocked`
- Includes the status **Reopened**

---

## 4) Deploy the ingestion services

The ingestion scripts are Functions Framework compatible. Each script exposes:

- `hello_http(request)` (HTTP handler)

Files (as requested):
- `ingest-jira.py`
- `ingest-jira-changelog.py`
- `ingest-testrail.py`
- `ingest-testrail-results.py`
- `ingest-bugsnag.py`

### Option A: Cloud Run (recommended)
A generic `Dockerfile` is included; build each service with a different `SOURCE_FILE`.

Example:
```bash
gcloud builds submit --tag gcr.io/YOUR_PROJECT/jira-ingest --build-arg SOURCE_FILE=ingest-jira.py .
gcloud run deploy jira-ingest --image gcr.io/YOUR_PROJECT/jira-ingest --region europe-west1 --allow-unauthenticated
```

Repeat for the other scripts changing `SOURCE_FILE`.

For `ingest-gamebench`, this repo also includes a ready-to-use Cloud Build pipeline (`cloudbuild.yaml`) that builds with `SOURCE_FILE=ingest-gamebench.py` and deploys the Cloud Run service `ingest-gamebench` in `europe-west1`.

### Option B: Local run
```bash
pip install -r requirements.txt
functions-framework --target=hello_http --source=ingest-jira.py --port=8080
```

---

## 5) Workflow Orchestrator

The existing orchestrator workflow is included:
- `workflows/qa_metrics_ingestion.yaml` (full ingestion; optional TestRail results incremental loop with continuation token support when `include_testrail_results: true`)

Use a single schedule for `qa_metrics_ingestion` and tune TestRail freshness with:
- `include_testrail_results: true`
- `testrail_results_days: 1`
- `testrail_results_max_iterations: 5`

Pass Jira keys explicitly in the workflow invocation (`project_keys_csv` or `project_keys`) so Jira and Jira changelog ingestion never run with empty keys. The workflow also accepts `jira_project_keys_csv` / `jira_project_keys` args and `JIRA_PROJECT_KEYS_CSV` / `JIRA_PROJECT_KEY` env fallbacks for compatibility with older scheduler payloads. It still hard-fails early when keys are missing.

Example invocation args:

```json
{
  "project_keys_csv": "GAME,PLATFORM",
  "lookback_days": 90,
  "include_testrail_results": true,
  "testrail_results_days": 1,
  "testrail_results_max_iterations": 5
}
```

---

## 6) Looker (LookML)

### Access control: Public vs Private KPIs
Privacy is enforced in the model with a Looker **user attribute**:

- `qa_is_lead` = `"yes"` → can see both public + private
- anything else → only public

### Files
- `models/panda_qa_metrics.model.lkml`
- `views/*.view.lkml`
- Dashboards:
  - `dashboards/qa_kpis_public.dashboard.lookml`
  - `dashboards/qa_kpis_private.dashboard.lookml`
  - `dashboards/qa_executive.dashboard.lookml`

### IMPORTANT
Update the model connection name:
- In `models/panda_qa_metrics.model.lkml` change:
  - `connection: "YOUR_BIGQUERY_CONNECTION"`

## KPI definitions (source-of-truth)

The definitions below are the canonical ones used by SQL/LookML in this repository. If a business definition changes, update the SQL views first and then align dashboard note text.

### Jira status mapping used by event-based KPIs

Source-of-truth: `qa_metrics.jira_status_category_map` in `bigquery/setup.sql`.

- `done_or_fixed` statuses:
  - `resolved`, `closed`, `verified`, `done`, `fixed`, `completed`, `qa approved`, `qa verified`, `ready for deploy`, `ready for release`, `released`, `in cert`
- `reopened_target` statuses:
  - `open`, `reopened`, `backlog`, `to do`, `in progress`, `selected for development`, `in review`, `ready for qa`, `ready for test`, `qa testing`, `in qa`, `testing`

Matching is case-insensitive and trim-tolerant (`LOWER(TRIM(status))`).

### Entered

- Meaning: bugs/defects created in period.
- Source-of-truth:
  - `qa_metrics.jira_bug_events_daily` (`event_type = 'created'`) for event-based trend tiles.
  - `qa_metrics.jira_issues_latest` filtered on `created_date` for current-state explore tiles.
- Logic: `COUNT(DISTINCT issue_key)` where issue type is `Bug` or `Defect` and event date is in selected window.

### Fixed

- Meaning: bugs/defects that transitioned into any `done_or_fixed` status.
- Source-of-truth: `qa_metrics.jira_bug_events_daily` (`event_type = 'fixed'`) and `qa_metrics.jira_fix_fail_rate_daily.fixed_count`.
- Logic: status change where normalized `to_status` is in `done_or_fixed`; aggregated as daily distinct issue count.

### Claimed fixed

- Meaning: first timestamp when a bug/defect reaches any `done_or_fixed` status.
- Source-of-truth: `qa_metrics.jira_mttr_claimed_fixed_daily`.
- Logic: `claimed_fixed_at = MIN(changed_at)` per issue where normalized `to_status` is in `done_or_fixed`.

### Reopened

- Meaning: bugs/defects that moved from done/fixed workflow back to active workflow.
- Source-of-truth: `qa_metrics.jira_bug_events_daily` (`event_type = 'reopened'`) and `qa_metrics.jira_fix_fail_rate_daily.reopened_count`.
- Logic: status change where normalized `from_status` is in `done_or_fixed` and normalized `to_status` is in `reopened_target`; aggregated as daily distinct issue count.

### Fix fail rate

- Meaning: reopened-to-fixed ratio in the same daily window.
- Source-of-truth: `qa_metrics.jira_fix_fail_rate_daily` and LookML measure `jira_fix_fail_rate_daily.fix_fail_rate`.
- Formula: `SUM(reopened_count) / NULLIF(SUM(fixed_count), 0)`.

### Active

This dashboard uses two active definitions intentionally; both should remain explicit in notes:

- Current backlog active (composition tiles):
  - Source-of-truth: `qa_metrics.jira_issues_latest`.
  - Logic: bug/defect issues with `status_category != 'Done'` (current snapshot).
- Active over time (trend tile):
  - Source-of-truth: `qa_metrics.jira_active_bug_count_daily`.
  - Logic: for each day in a date spine, count bugs with `created_date <= metric_date` and (`fixed_date IS NULL OR fixed_date > metric_date`), where `fixed_date` is earliest status change to `Resolved`, `Closed`, or `Verified`.

### MTTR (hours)

- Meaning: average time from bug creation to first claimed fixed transition.
- Source-of-truth: `qa_metrics.jira_mttr_claimed_fixed_daily` and LookML explore `jira_mttr_claimed_fixed_daily`.
- Logic:
  - `claimed_fixed_at = MIN(changed_at)` where normalized `to_status` is in `done_or_fixed`.
  - `avg_mttr_hours = AVG(TIMESTAMP_DIFF(claimed_fixed_at, created, SECOND) / 3600.0)`.
  - Guard: exclude invalid rows where `claimed_fixed_at < created`.

### Bugsnag active + severity (dashboard alignment)

- Active Bugsnag error:
  - Source-of-truth: LookML `views/bugsnag_errors_latest.view.lkml` measure `active_errors`.
  - Logic: `is_active = LOWER(IFNULL(status, '')) NOT IN ('fixed','resolved','closed')`; `active_errors = COUNT(*)` filtered to `is_active = yes`.
- High/Critical active Bugsnag errors:
  - Source-of-truth: same view, measure `high_critical_active_errors`.
  - Logic: active errors with `severity IN ('critical','error')`.
- Severity note for consumers:
  - Bugsnag tiles use raw Bugsnag severities (`critical`, `error`, `warning`, `info`, etc.) in the Bugsnag explore.
  - In consolidated KPI facts (`qa_metrics.qa_kpi_facts`), severity is normalized for cross-source reporting (`error -> High`, `warning -> Medium`, `info -> Low`).

---

## Notes / Known assumptions

- Some KPIs (e.g. escape/leak rates) are implemented as **practical proxies** because the KPI sheets don't provide a direct mapping between pre-release defects and production defects per release. You can improve accuracy by filling:
  - `qa_metrics.source_project_mapping` (map Bugsnag/TestRail project ids -> POD/Feature/Release)
  - `qa_metrics.release_calendar` (define release windows)
- Snapshot KPIs (open backlog, active errors, bugs assigned) are derived from **current state**. If you want true history, run a daily scheduled query that stores snapshots into `manual_kpi_values`.

---

## Quick checklist

1. Create secrets in Secret Manager ✅
2. Deploy 5 ingestion services ✅
3. Run `bigquery/setup.sql` ✅
4. In Looker:
   - create project from this repo
   - set connection name
   - create user attribute `qa_is_lead`
5. Open dashboards ✅
