-- QA Metrics Pipeline setup (idempotent)
-- Project: qa-panda-metrics
-- Dataset: qa_metrics_simple
--
-- Run with:
--   bq query --location=EU --use_legacy_sql=false < setup.sql
--
-- Notes:
-- - Uses CREATE TABLE IF NOT EXISTS.
-- - Also adds missing columns for existing tables (via INFORMATION_SCHEMA checks).

-- -----------------------------------------------------------------------------
-- ingestion_state (incremental cursors)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.ingestion_state` (
  source STRING NOT NULL,
  last_run TIMESTAMP NOT NULL,
  state_key STRING
)
PARTITION BY DATE(last_run)
CLUSTER BY source, state_key;

-- Ensure required columns exist (for older table variants)
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'ingestion_state' AND column_name = 'source'
  ) THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.ingestion_state` ADD COLUMN source STRING';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'ingestion_state' AND column_name = 'last_run'
  ) THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.ingestion_state` ADD COLUMN last_run TIMESTAMP';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'ingestion_state' AND column_name = 'state_key'
  ) THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.ingestion_state` ADD COLUMN state_key STRING';
  END IF;
END;

-- -----------------------------------------------------------------------------
-- Jira
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` (
  snapshot_timestamp TIMESTAMP NOT NULL,
  issue_id STRING,
  issue_key STRING,
  issue_type STRING,
  summary STRING,
  status STRING,
  status_category STRING,
  priority STRING,
  severity STRING,
  pod_team STRING,
  fix_versions ARRAY<STRING>,
  assignee_email STRING,
  reporter_email STRING,
  created TIMESTAMP,
  updated TIMESTAMP
)
PARTITION BY DATE(snapshot_timestamp)
CLUSTER BY issue_key, status_category, priority;

CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.jira_changelog` (
  change_timestamp TIMESTAMP NOT NULL,
  issue_id STRING,
  issue_key STRING,
  field STRING,
  from_value STRING,
  to_value STRING,
  author_email STRING
)
PARTITION BY DATE(change_timestamp)
CLUSTER BY issue_key, field, to_value;

-- Add missing columns (for older deployments)
BEGIN
  -- jira_issues_snapshot
  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='status_category') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN status_category STRING';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='issue_type') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN issue_type STRING';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='pod_team') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN pod_team STRING';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='fix_versions') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN fix_versions ARRAY<STRING>';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='severity') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN severity STRING';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='assignee_email') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN assignee_email STRING';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_issues_snapshot' AND column_name='reporter_email') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_issues_snapshot` ADD COLUMN reporter_email STRING';
  END IF;

  -- jira_changelog
  IF NOT EXISTS (SELECT 1 FROM `qa-panda-metrics.qa_metrics_simple.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name='jira_changelog' AND column_name='issue_id') THEN
    EXECUTE IMMEDIATE 'ALTER TABLE `qa-panda-metrics.qa_metrics_simple.jira_changelog` ADD COLUMN issue_id STRING';
  END IF;
END;

-- -----------------------------------------------------------------------------
-- TestRail
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.testrail_results` (
  ingest_timestamp TIMESTAMP NOT NULL,
  result_id INT64,
  project_id INT64,
  run_id INT64,
  run_name STRING,
  suite_id INT64,
  suite_name STRING,
  test_id INT64,
  case_id INT64,
  status_id INT64,
  status STRING,
  created_on TIMESTAMP,
  assignedto_id INT64,
  comment STRING
)
PARTITION BY DATE(created_on)
CLUSTER BY project_id, run_id, status_id;

-- -----------------------------------------------------------------------------
-- BugSnag
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.bugsnag_errors` (
  ingest_timestamp TIMESTAMP NOT NULL,
  project_id STRING,
  error_id STRING,
  error_class STRING,
  message STRING,
  severity STRING,
  status STRING,
  first_seen TIMESTAMP,
  last_seen TIMESTAMP,
  events INT64,
  users INT64,
  release_stages ARRAY<STRING>
)
PARTITION BY DATE(ingest_timestamp)
CLUSTER BY project_id, severity, status;

-- -----------------------------------------------------------------------------
-- GameBench
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.gamebench_sessions` (
  ingest_timestamp TIMESTAMP NOT NULL,
  session_id STRING,
  user_email STRING,
  app_name STRING,
  app_package STRING,
  device_model STRING,
  platform STRING,
  time_pushed TIMESTAMP,
  median_fps FLOAT64,
  fps_stability_pct FLOAT64
)
PARTITION BY DATE(time_pushed)
CLUSTER BY app_package, platform;

CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.manual_build_size` (
  metric_date DATE NOT NULL,
  platform STRING NOT NULL,
  build_size_mb FLOAT64 NOT NULL,
  updated_at TIMESTAMP NOT NULL
)
PARTITION BY metric_date
CLUSTER BY platform;

-- -----------------------------------------------------------------------------
-- Executive KPI output (normalized)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `qa-panda-metrics.qa_metrics_simple.qa_executive_kpis` (
  computed_at TIMESTAMP NOT NULL,
  metric_id STRING NOT NULL,
  metric_name STRING,
  metric_date DATE NOT NULL,
  window_start DATE,
  window_end DATE,
  dimensions STRING,      -- JSON string like {"severity":"S1","priority":"High"}
  value FLOAT64,
  numerator FLOAT64,
  denominator FLOAT64,
  source STRING
)
PARTITION BY metric_date
CLUSTER BY metric_id;

CREATE OR REPLACE VIEW `qa-panda-metrics.qa_metrics_simple.qa_executive_kpis_latest` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    k.*,
    ROW_NUMBER() OVER (
      PARTITION BY metric_id, metric_date, IFNULL(dimensions, "{}")
      ORDER BY computed_at DESC
    ) AS rn
  FROM `qa-panda-metrics.qa_metrics_simple.qa_executive_kpis` k
)
WHERE rn = 1;
