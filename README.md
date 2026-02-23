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
- `JIRA_SITE` (e.g. `https://yourcompany.atlassian.net`)
- `JIRA_USER` (email)
- `JIRA_API_TOKEN`

### TestRail
- `TESTRAIL_BASE_URL` (e.g. `https://testrail.yourcompany.com`)
- `TESTRAIL_USER`
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

**Manual Public KPIs:** P27, P28, P29, P30, P35, P36, P37, P38, P40, P41, P42  
**Manual Private KPIs:** R1, R10, R17, R18, R19, R2, R20, R24, R3, R4, R5

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

If these refreshes are skipped, Looker explores can compile correctly but charts may render with no rows.

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

### Option B: Local run
```bash
pip install -r requirements.txt
functions-framework --target=hello_http --source=ingest-jira.py --port=8080
```

---

## 5) Workflow Orchestrator

The existing orchestrator workflow is included:
- `workflows/qa_metrics_ingestion.yaml`

It calls each ingestion service URL (Cloud Run).

---

## 6) Looker (LookML)

### Access control: Public vs Private KPIs
Privacy is enforced in the model with a Looker **user attribute**:

- `qa_is_lead` = `"yes"` → can see both public + private
- anything else → only public

### Files
- `models/qa_metrics.model.lkml`
- `views/*.view.lkml`
- Dashboards:
  - `dashboards/qa_kpis_public.dashboard.lookml`
  - `dashboards/qa_kpis_private.dashboard.lookml`

### IMPORTANT
Update the model connection name:
- In `models/qa_metrics.model.lkml` change:
  - `connection: "YOUR_BIGQUERY_CONNECTION"`

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
