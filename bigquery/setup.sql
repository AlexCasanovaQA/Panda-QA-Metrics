-- Panda QA Metrics - BigQuery setup
-- Dataset default: qa_metrics
-- IMPORTANT: adjust dataset location if needed.

BEGIN

-- Keep only required objects (drops everything else in dataset)
DECLARE keep_objects ARRAY<STRING> DEFAULT [

  -- Raw ingestion tables (as used by current code defaults)
  'jira_issues_v2',
  'jira_changelog_v2',
  'testrail_runs',
  'testrail_results',
  'bugsnag_errors',
  'gamebench_sessions_v1',

  -- Manual/mapping/source tables
  'manual_kpi_values',
  'source_project_mapping',
  'qa_user_crosswalk',
  'release_calendar',
  'build_size_manual',
  'gamebench_daily_metrics',

  -- Derived views used by Looker
  'kpi_catalog',
  'jira_issues_latest',
  'testrail_runs_latest',
  'bugsnag_errors_latest',
  'jira_status_changes',
  'jira_bug_events_daily',
  'jira_fix_fail_rate_daily',
  'jira_mttr_fixed_daily',
  'jira_mttr_claimed_fixed_daily',
  'jira_active_bug_count_daily',
  'testrail_bvt_latest',
  'qa_kpi_facts',
  'qa_kpi_facts_enriched',
  'gamebench_sessions_latest'
];

CREATE SCHEMA IF NOT EXISTS `qa_metrics` OPTIONS(location="US");

FOR obj IN (
  SELECT table_name, table_type
  FROM `qa_metrics`.INFORMATION_SCHEMA.TABLES
  WHERE table_name NOT IN UNNEST(keep_objects)
)
DO
  EXECUTE IMMEDIATE FORMAT(
    'DROP %s `qa_metrics.%s`',
    IF(obj.table_type = 'VIEW', 'VIEW', 'TABLE'),
    obj.table_name
  );
END FOR;

-- -----------------------------
-- Manual KPI inputs (for KPIs that cannot be fully automated)
-- -----------------------------
CREATE TABLE IF NOT EXISTS `qa_metrics.manual_kpi_values` (
  kpi_id STRING,
  kpi_name STRING,
  privacy_level STRING, -- 'public' | 'private'
  metric_date DATE,
  pod STRING,
  feature STRING,
  release STRING,
  sprint STRING,
  qa_user STRING,
  developer_user STRING,
  severity STRING,
  numerator FLOAT64,
  denominator FLOAT64,
  value FLOAT64,
  unit STRING,
  notes STRING,
  source STRING,
  _ingested_at TIMESTAMP
)
PARTITION BY metric_date
CLUSTER BY kpi_id, privacy_level, pod, feature;

-- -----------------------------
-- Optional mapping tables
-- -----------------------------
CREATE TABLE IF NOT EXISTS `qa_metrics.source_project_mapping` (
  source STRING,              -- 'testrail' | 'bugsnag'
  source_project_id STRING,   -- project id as string
  pod STRING,
  feature STRING,
  release STRING,
  platform STRING,
  notes STRING,
  _updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `qa_metrics.qa_user_crosswalk` (
  canonical_qa_user STRING,
  jira_account_id STRING,
  jira_display_name STRING,
  testrail_user_id INT64,
  testrail_user_name STRING,
  qa_group STRING,
  pod STRING,
  is_active BOOL,
  _updated_at TIMESTAMP
);

-- Optional: release calendar (needed if you want truly "per release" KPIs for Bugsnag)
CREATE TABLE IF NOT EXISTS `qa_metrics.release_calendar` (
  release STRING,
  start_date DATE,
  end_date DATE,
  notes STRING,
  _updated_at TIMESTAMP
);

CREATE OR REPLACE VIEW `qa_metrics.kpi_catalog` AS
SELECT 'P1' AS kpi_id, 'Defects Created' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Volume' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of new defect tickets created in the selected period.' AS description, 'Jira' AS data_sources, 'COUNT of issues where issue_type = "Bug" and created date is in the period.' AS calculation, 'Per POD / feature / release / sprint' AS granularity, 'Weekly, per sprint, per release' AS time_window, 'No fixed target; monitor trend and unexpected spikes per POD.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Line chart by sprint; split by priority, component, QA Group (Dev vs External).' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P2' AS kpi_id, 'Defects Closed' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Volume' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of defect tickets resolved or closed in the selected period.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues with resolutiondate in the period and status in Done/Resolved/Closed.' AS calculation, 'Per POD / feature / release / sprint' AS granularity, 'Weekly, per sprint, per release' AS time_window, 'Over time, Closed >= Created to avoid backlog growth.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Plot together with P1 as "Created vs Closed" trend.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P3' AS kpi_id, 'Defects Reopened' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of defect tickets that were reopened after being resolved.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues that transition from resolved/closed back to an open/reopened status during the period.' AS calculation, 'Per POD / feature / release / sprint' AS granularity, 'Weekly, per sprint' AS time_window, 'As low as possible; aim for <3% of closed defects.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Bar chart per POD; requires Jira status history or explicit "Reopened" status.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P4' AS kpi_id, 'Defect Reopen Rate' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of closed defects that were subsequently reopened.' AS description, 'Jira' AS data_sources, 'P3 (Defects Reopened) / P2 (Defects Closed) in the same period.' AS calculation, 'Per POD / feature / release / sprint' AS granularity, 'Weekly, per sprint, rolling 4 weeks' AS time_window, 'Target <3–5%; stricter limit for Critical/High.' AS target_threshold, 'QA Director / POD QA Leads' AS owner_role, 'Line chart by sprint; filter by priority and QA Group.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P5' AS kpi_id, 'Open Defect Backlog' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Backlog' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Total number of unresolved defects at the end of the period.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues where resolutiondate IS NULL or status not in Done/Resolved/Closed at snapshot.' AS calculation, 'Per POD / feature / release / game' AS granularity, 'Snapshot at end of week / sprint / release' AS time_window, 'Backlog stable or trending down; critical backlog subject to strict limits.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Stacked bar by priority; use snapshot filter date.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P6' AS kpi_id, 'Open Critical & High Defects' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Risk' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of unresolved Critical and High priority defects.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues where priority in ("Blocker","Critical","High") and resolutiondate IS NULL.' AS calculation, 'Per POD / feature / release / game' AS granularity, 'Snapshot at end of week / sprint / release' AS time_window, 'Target 0 open Critical at release; High below agreed limit per feature.' AS target_threshold, 'POD QA Lead / Engineering Manager' AS owner_role, 'KPI tiles per severity; used in release gates and alerts.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P7' AS kpi_id, 'Average Age of Open Defects' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Flow / Age' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Average number of days that currently open bugs have been unresolved.' AS description, 'Jira' AS data_sources, 'Average DAYS between snapshot date and created for bugs where resolutiondate IS NULL.' AS calculation, 'Per POD / feature / priority' AS granularity, 'Snapshot (trend weekly)' AS time_window, 'P0/P1 should have very low average age (for example <7 days).' AS target_threshold, 'POD QA Lead' AS owner_role, 'Bar chart by priority; histogram of age buckets for backlog hygiene.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P8' AS kpi_id, 'Defect Density (Bugs per 100 Story Points)' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Defects created relative to the amount of delivered work.' AS description, 'Jira' AS data_sources, 'Bugs created in sprint / completed story points in same sprint * 100.' AS calculation, 'Per POD / release / sprint' AS granularity, 'Per sprint / release' AS time_window, 'Benchmark per POD; track trend, not absolute value.' AS target_threshold, 'QA Director / Product Owner' AS owner_role, 'Column chart per sprint; compare across PODs.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P9' AS kpi_id, 'Time to Triage' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Flow & Time (Jira)' AS subsection, 'Flow / SLA' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Average time from defect creation until it reaches the agreed triage state.' AS description, 'Jira' AS data_sources, 'Average HOURS between created and first timestamp where status is triage state.' AS calculation, 'Per POD / feature / priority' AS granularity, 'Per sprint; rolling 4 weeks' AS time_window, 'Target <24h for Critical/High defects.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Box or bar chart by priority; requires status history ingestion.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P10' AS kpi_id, 'Time to Resolution (MTTR)' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Flow & Time (Jira)' AS subsection, 'Flow / SLA' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Average time from defect creation until resolution.' AS description, 'Jira' AS data_sources, 'Average DAYS between created and resolutiondate for bugs resolved in period.' AS calculation, 'Per POD / feature / priority' AS granularity, 'Per sprint; rolling 4 and 12 weeks' AS time_window, 'Critical issues resolved within agreed SLA (for example <3 days).' AS target_threshold, 'Engineering Manager / QA Lead' AS owner_role, 'Trend line by severity; show P95 as additional series.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P11' AS kpi_id, 'SLA Compliance for Critical/High Defects' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Flow & Time (Jira)' AS subsection, 'SLA' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of Critical/High defects resolved within the agreed resolution SLA.' AS description, 'Jira' AS data_sources, 'Resolved Critical/High bugs within SLA window / total Critical/High resolved in period.' AS calculation, 'Per POD / release / sprint' AS granularity, 'Per sprint; rolling 4 weeks' AS time_window, 'Target >=95% for Critical, >=90% for High.' AS target_threshold, 'Engineering Manager / QA Director' AS owner_role, 'Gauge or bar by POD; feed into quality gate.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P12' AS kpi_id, 'Test Runs Executed' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Volume' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of TestRail runs executed in the selected period.' AS description, 'TestRail' AS data_sources, 'COUNT of runs where created_on or completed_on is in the period.' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Daily, per sprint, per release' AS time_window, 'Match planned runs for the cycle; no systematic misses.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Column chart per day/sprint; filter by QA Group and milestone.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P13' AS kpi_id, 'Test Cases Executed' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Throughput' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Total test cases executed (passed, failed, blocked, retest).' AS description, 'TestRail' AS data_sources, 'SUM(passed_count + failed_count + blocked_count + retest_count).' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Daily, per sprint, per release' AS time_window, 'Should align with planned coverage for release / test plan.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Line chart; stacked bar by status where useful.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P14' AS kpi_id, 'Pass Rate' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of executed test cases that passed.' AS description, 'TestRail' AS data_sources, 'SUM(passed_count) / SUM(passed_count + failed_count + blocked_count + retest_count).' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Daily, per sprint, per release' AS time_window, 'Target for release builds typically >=95% depending on risk.' AS target_threshold, 'POD QA Lead / Release Manager' AS owner_role, 'KPI tile plus trend line; slice by QA Group and environment.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P15' AS kpi_id, 'Fail Rate' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of executed test cases that failed.' AS description, 'TestRail' AS data_sources, 'SUM(failed_count) / SUM(passed_count + failed_count + blocked_count + retest_count).' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Daily, per sprint, per release' AS time_window, 'Should trend down as release stabilises.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Stacked bar Pass/Fail/Blocked/Retest per sprint.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P16' AS kpi_id, 'Blocked Rate' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Health / Environment' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of executed test cases that are blocked by environment, data or dependencies.' AS description, 'TestRail' AS data_sources, 'SUM(blocked_count) / SUM(passed_count + failed_count + blocked_count + retest_count).' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Daily, per sprint, per release' AS time_window, 'Keep <5% where possible; spikes indicate infra issues.' AS target_threshold, 'QA Env Owner / POD QA Lead' AS owner_role, 'Bar chart by environment/config; critical for capacity planning.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P17' AS kpi_id, 'Retest Rate' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Stability' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of executed test cases that required retest.' AS description, 'TestRail' AS data_sources, 'SUM(retest_count) / SUM(passed_count + failed_count + blocked_count + retest_count).' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Per sprint, per release' AS time_window, 'High retest rate may indicate unstable builds or late fixes.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Trend line per milestone; compare across QA Groups.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P18' AS kpi_id, 'Test Coverage (Executed vs Planned)' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Coverage' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Coverage of planned test cases that were actually executed.' AS description, 'TestRail' AS data_sources, 'Executed tests / (executed tests + untested_count).' AS calculation, 'Per POD / project / milestone / config / QA Group' AS granularity, 'Per sprint, per release' AS time_window, 'Typical gate >=90–95% depending on risk profile.' AS target_threshold, 'POD QA Lead / Release Manager' AS owner_role, 'Gauge or bar per milestone; used in quality gate.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P19' AS kpi_id, 'Average Test Run Duration' AS kpi_name, 'public' AS privacy_level, 'Test Execution & Coverage' AS section, 'Test Runs & Results (TestRail)' AS subsection, 'Process / Time' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Average duration of TestRail runs from creation to completion.' AS description, 'TestRail' AS data_sources, 'Average HOURS between created_on and completed_on for completed runs.' AS calculation, 'Per POD / project / milestone / suite / QA Group' AS granularity, 'Per sprint; rolling 4 weeks' AS time_window, 'No strict target; watch for anomalies and long tails.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Box plot per suite/config; compare Dev vs External QA.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P20' AS kpi_id, 'Active Production Errors' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Bugsnag Errors' AS subsection, 'Risk' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of distinct Bugsnag errors that are still active (not fixed).' AS description, 'Bugsnag' AS data_sources, 'COUNT DISTINCT error_id where status != "fixed" and last_seen within monitoring window.' AS calculation, 'Per project / platform / release' AS granularity, 'Daily snapshot; weekly trend' AS time_window, 'Should trend down; specific thresholds per game.' AS target_threshold, 'LiveOps QA Lead / Incident Manager' AS owner_role, 'KPI tiles per severity; main prod health snapshot.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P21' AS kpi_id, 'High/Critical Active Errors' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Bugsnag Errors' AS subsection, 'Risk' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of active production errors with high severity.' AS description, 'Bugsnag' AS data_sources, 'COUNT DISTINCT error_id where severity in ("error","critical") AND status != "fixed".' AS calculation, 'Per project / platform / release' AS granularity, 'Daily snapshot; weekly trend' AS time_window, 'Aim for zero open critical errors.' AS target_threshold, 'LiveOps QA Lead / Eng Manager' AS owner_role, 'Dedicated tile and alerting; used in Go/No-Go for live promotions.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P22' AS kpi_id, 'New Production Errors' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Bugsnag Errors' AS subsection, 'Stability' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Distinct Bugsnag errors first seen in the current period.' AS description, 'Bugsnag' AS data_sources, 'COUNT DISTINCT error_id where first_seen date is in the period.' AS calculation, 'Per project / platform / release' AS granularity, 'Daily, per sprint, per release' AS time_window, 'Should drop as release matures; spikes after release show regressions.' AS target_threshold, 'LiveOps QA Lead' AS owner_role, 'Bar chart by release/platform; filter by severity.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P23' AS kpi_id, 'Total Error Events (Live Incident Rate)' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Bugsnag Errors' AS subsection, 'Live Incident Rate' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Total number of error events captured by Bugsnag in the period.' AS description, 'Bugsnag' AS data_sources, 'SUM(events) for errors where last_seen is inside the period.' AS calculation, 'Per project / platform / severity' AS granularity, 'Daily, weekly; rolling 30 days' AS time_window, 'Trend down over time; alerts on deviations from baseline.' AS target_threshold, 'LiveOps QA Lead / SRE' AS owner_role, 'Line chart with severity split; optionally normalise by DAU.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P24' AS kpi_id, 'Users Impacted by Errors' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Bugsnag Errors' AS subsection, 'Customer Impact' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Total number of users affected by Bugsnag errors in the period (approximate).' AS description, 'Bugsnag' AS data_sources, 'SUM(users) for errors where last_seen is in the period.' AS calculation, 'Per project / platform / severity' AS granularity, 'Daily, weekly; rolling 30 days' AS time_window, 'Minimise, especially for high severity issues.' AS target_threshold, 'LiveOps QA Lead / Product Owner' AS owner_role, 'KPI tile plus trend line; used in incident reviews.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P25' AS kpi_id, 'Average Error Lifetime' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Bugsnag Errors' AS subsection, 'Flow / Age' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Average time between first_seen and last_seen for resolved errors.' AS description, 'Bugsnag' AS data_sources, 'Average DAYS between first_seen and last_seen for errors marked as fixed or inactive.' AS calculation, 'Per project / severity' AS granularity, 'Rolling 30 days or per release' AS time_window, 'Shorter lifetimes indicate faster detection & fix rollout.' AS target_threshold, 'LiveOps QA Lead / Eng Manager' AS owner_role, 'Box plot by severity; correlate with Jira MTTR.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P26' AS kpi_id, 'Defects per 100 Test Cases Executed' AS kpi_name, 'public' AS privacy_level, 'Combined Quality & Outcomes' AS section, 'Cross-tool Metrics' AS subsection, 'Quality Yield' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Ratio of defects found to test cases executed, indicating defect yield.' AS description, 'Jira + TestRail' AS data_sources, '(Bugs created in period / Executed test cases in period) * 100.' AS calculation, 'Per POD / feature / release / sprint / QA Group' AS granularity, 'Per sprint, per release' AS time_window, 'Used comparatively across releases and QA Groups.' AS target_threshold, 'QA Director / POD QA Leads' AS owner_role, 'Column chart by sprint; separate series for Dev QA vs External QA.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P27' AS kpi_id, 'Production Incidents per Release' AS kpi_name, 'public' AS privacy_level, 'Combined Quality & Outcomes' AS section, 'Cross-tool Metrics' AS subsection, 'Outcome' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Number of high-severity production incidents associated with a release.' AS description, 'Bugsnag (+ Jira release mapping)' AS data_sources, 'COUNT DISTINCT high/critical Bugsnag errors mapped to a release.' AS calculation, 'Per release / POD / platform' AS granularity, 'Per release' AS time_window, 'Goal: zero or minimal critical incidents per release.' AS target_threshold, 'QA Director / Product Owner' AS owner_role, 'Bar chart by release; annotate big launches.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P28' AS kpi_id, 'Release Quality Gate Status' AS kpi_name, 'public' AS privacy_level, 'Combined Quality & Outcomes' AS section, 'Cross-tool Metrics' AS subsection, 'Quality Gate / Boolean' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Pass/Fail indicator summarising whether a release meets severity thresholds and coverage targets.' AS description, 'Jira + TestRail + Bugsnag' AS data_sources, 'Gate PASS if: coverage >= threshold; 0 open Critical; High backlog under limit; SLA compliance above target; incident rate below threshold.' AS calculation, 'Per release / POD' AS granularity, 'Evaluated at each RC and before launch' AS time_window, 'All launches should meet gate or be explicitly waived.' AS target_threshold, 'QA Director / Game Leadership' AS owner_role, 'Table with PASS/FAIL per release and which criteria failed.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P29' AS kpi_id, 'Hands-on Testing Time % (Team)' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Time Use' AS kpi_type, 'Dev QA and External QA (compare)' AS qa_group_scope, 'Percentage of QA time spent on hands-on testing activities for each team.' AS description, 'Time tracking / manual logs' AS data_sources, 'Hands-On hours / total QA hours in the period.' AS calculation, 'Per POD / QA Group / site' AS granularity, 'Weekly, per sprint, per quarter' AS time_window, 'Target 75% Hands-On at team level.' AS target_threshold, 'QA Manager' AS owner_role, '100% stacked bar per QA Group; target reference line at 75%.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P30' AS kpi_id, 'Non Hands-on Time % (Team)' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Time Use' AS kpi_type, 'Dev QA and External QA (compare)' AS qa_group_scope, 'Percentage of QA time spent on non hands-on activities (test design, meetings, training, pre-mastering).' AS description, 'Time tracking / manual logs' AS data_sources, 'Non Hands-On hours / total QA hours in the period.' AS calculation, 'Per POD / QA Group / site' AS granularity, 'Weekly, per sprint, per quarter' AS time_window, 'Target around 25% Non Hands-On.' AS target_threshold, 'QA Manager' AS owner_role, 'Visualised together with P29 as complement of 100%.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P31' AS kpi_id, 'Bug Escape Rate (by severity)' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Share of defects that escape to production, broken down by severity (Blocker/Critical/Major).' AS description, 'Jira + Bugsnag' AS data_sources, '(Defects found in production / (Pre-release defects + production defects)) by severity.' AS calculation, 'Per POD / feature / release' AS granularity, 'Per release and weekly' AS time_window, 'High expectation: 0–2% Blocker/Critical; <4% Majors.' AS target_threshold, 'QA Director / Product Owner' AS owner_role, 'Stacked bar per severity; used as core OS expectation metric.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P32' AS kpi_id, 'Defect Detection Efficiency (DDE)' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of total defects for a release that were detected before going to production.' AS description, 'Jira + Bugsnag' AS data_sources, 'Pre-release defects / (Pre-release + post-release defects) * 100.' AS calculation, 'Per POD / release / feature' AS granularity, 'Per release and monthly' AS time_window, 'High expectation: >90% coverage; minimum acceptable ≥85%.' AS target_threshold, 'QA Director' AS owner_role, 'Gauge per release; show distribution across PODs.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P33' AS kpi_id, 'Bug Rejection Rate' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, "Percentage of reported bugs that are rejected as not valid (Not a Bug, Won't Fix, Duplicate)." AS description, 'Jira' AS data_sources, 'Rejected bugs / total bugs closed in the period.' AS calculation, 'Per POD / QA Group / feature' AS granularity, 'Weekly and per release' AS time_window, 'High expectation: <5% overall.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar chart by POD and QA Group; high values signal training needs.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P34' AS kpi_id, 'Bug Report Completeness' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of bug reports that meet minimum reproducibility standard (screenshots, logs, steps, build info).' AS description, 'Jira (custom fields / templates)' AS data_sources, 'Number of bugs marked as complete / total bugs reported in the period.' AS calculation, 'Per POD / QA Group' AS granularity, 'Weekly' AS time_window, 'High expectation: >99% of bugs meet completeness standard.' AS target_threshold, 'QA Manager' AS owner_role, 'KPI tile; optionally use checklist automation or JQL filters.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P35' AS kpi_id, 'Execution Result Accuracy' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Testing Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Accuracy of test results recorded vs actual outcome (how often initial result is later changed).' AS description, 'TestRail (per-case history)' AS data_sources, '1 - (Incorrect or changed results / total executed tests).' AS calculation, 'Per POD / suite / QA Group' AS granularity, 'Per test cycle' AS time_window, 'High expectation: very high accuracy (≈99%).' AS target_threshold, 'POD QA Lead' AS owner_role, 'Requires case-level data; approximation via retest/blocked analysis if needed.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P36' AS kpi_id, 'Severity Assignment Accuracy' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of bugs whose initial severity matches the final agreed severity.' AS description, 'Jira' AS data_sources, 'Correct severity assignments / total bugs, where correct = no change or change within agreed tolerance.' AS calculation, 'Per POD / QA Group / severity' AS granularity, 'Weekly and per release' AS time_window, 'High expectation: close to 100%; specific tolerance per team.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar chart by QA Group and severity level; used for training.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P37' AS kpi_id, 'Test Execution Throughput (cases per person‑day)' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Throughput' AS kpi_type, 'Dev QA and External QA (compare)' AS qa_group_scope, 'Average number of test cases executed per QA person‑day.' AS description, 'TestRail + time tracking' AS data_sources, 'Executed test cases / QA testing hours converted to person‑days.' AS calculation, 'Per POD / QA Group / suite' AS granularity, 'Daily and per test cycle' AS time_window, 'Target depends on game and complexity; watch trend rather than absolute.' AS target_threshold, 'QA Manager' AS owner_role, 'Box/violin plot per POD; compare Dev QA vs Amber/GSQA.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P38' AS kpi_id, 'Bug Reporting Lead Time' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Time' AS kpi_type, 'Dev QA and External QA (compare)' AS qa_group_scope, 'Average time between discovering an issue and logging it as a bug.' AS description, 'Time tracking + Jira' AS data_sources, 'Average minutes from detection to bug creation.' AS calculation, 'Per POD / QA Group' AS granularity, 'Daily' AS time_window, 'High expectation: very low (for example <15 minutes for most issues).' AS target_threshold, 'QA Manager' AS owner_role, 'Line chart; useful to ensure rapid defect capture during sessions.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P39' AS kpi_id, 'Fix Verification Cycle Time' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Time' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Average time from a fix being ready for QA to verification completed.' AS description, 'Jira + TestRail / time tracking' AS data_sources, 'Average hours between dev-ready and QA verification completion.' AS calculation, 'Per POD / QA Group / severity' AS granularity, 'Daily and per release' AS time_window, 'Targets per severity (e.g., same‑day for Critical).' AS target_threshold, 'POD QA Lead' AS owner_role, 'Bar chart by severity; feed into SLA discussions with dev.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P40' AS kpi_id, 'Exploratory Session Reporting Coverage' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Reporting' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Coverage and time spent in documented exploratory testing sessions.' AS description, 'Time tracking / exploratory session logs' AS data_sources, 'Documented exploratory sessions / total exploratory sessions; plus total hours.' AS calculation, 'Per POD / QA Group / area' AS granularity, 'Weekly' AS time_window, 'High expectation: near 100% of exploratory sessions documented.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar chart of coverage % plus hours as second axis.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P41' AS kpi_id, 'Time to Flag' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Communication' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Time to escalate and communicate critical risks/blockers from detection to correct channel.' AS description, 'Time tracking / comms tools (Slack, etc.)' AS data_sources, 'Average minutes from risk detection to first flag.' AS calculation, 'Per POD / QA Group' AS granularity, 'Daily' AS time_window, 'Expectation: very quick (for example within same test session).' AS target_threshold, 'QA Manager / Production' AS owner_role, 'Used in incident postmortems; can be approximated manually at first.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P42' AS kpi_id, 'Response Time SLA (Comms interaction)' AS kpi_name, 'public' AS privacy_level, 'Team Focus & OS Expectations' AS section, 'OS Expectations KPIs (Per POD)' AS subsection, 'OS / Communication' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Time QA takes to acknowledge and respond to urgent vs general requests in communication channels.' AS description, 'Comms tools + time tracking' AS data_sources, 'Average response time in minutes, tracked separately for urgent vs general.' AS calculation, 'Per POD / QA Group' AS granularity, 'Weekly' AS time_window, 'High expectation: <10 min for urgent, <30 min for general requests.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar or box plot; tie into collaboration OS expectations.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'P43' AS kpi_id, 'Defect Acceptance Ratio (DAR)' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Quality / Effectiveness' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of reported defects that are accepted as valid (not rejected as NAB, Duplicate, Won’t Fix).' AS description, 'Jira' AS data_sources, 'Accepted bugs / total bugs closed in the period * 100' AS calculation, 'Per POD / QA Group / feature' AS granularity, 'Weekly, per sprint, per release' AS time_window, 'Target >=92%' AS target_threshold, 'QA Manager / POD QA Lead' AS owner_role, 'KPI tile + trend; low DAR indicates poor bug quality or requirement gaps' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P44' AS kpi_id, 'High Severity Defect Reporting Rate (P0+P1)' AS kpi_name, 'public' AS privacy_level, 'Defects & Testing' AS section, 'Defects (Jira)' AS subsection, 'Risk / Severity Focus' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of total reported defects that are P0 or P1 severity.' AS description, 'Jira' AS data_sources, '(P0 + P1 bugs reported) / total bugs reported * 100' AS calculation, 'Per POD / QA Group / release' AS granularity, 'Weekly, per sprint, per release' AS time_window, 'Target >=25% Depending on The milestone phase' AS target_threshold, 'POD QA Lead / QA Director' AS owner_role, 'Column chart by severity; ensures focus on meaningful defects over noise' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P45' AS kpi_id, 'NMI Rate (No-Merge / Not Meaningful Issues)' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Production Bugs' AS subsection, 'Signal Quality' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of reported defects classified as NMI (issues that do not require a code fix or merge).' AS description, 'Jira' AS data_sources, 'NMI bugs / total bugs closed * 100' AS calculation, 'Per POD / QA Group' AS granularity, 'Weekly, per sprint' AS time_window, 'Target <=5%' AS target_threshold, 'QA Manager' AS owner_role, 'High NMI indicates requirement clarity or test expectation issues' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'P46' AS kpi_id, 'Defect Leak Rate (Live)' AS kpi_name, 'public' AS privacy_level, 'Production Quality & Incidents' AS section, 'Live Defects' AS subsection, 'Outcome / Customer Impact' AS kpi_type, 'Both (Dev QA & External QA)' AS qa_group_scope, 'Percentage of total defects that were first identified in live/production.' AS description, 'Jira + Bugsnag' AS data_sources, 'Live defects / (pre-release defects + live defects) * 100' AS calculation, 'Per POD / release / platform' AS granularity, 'Per release; rolling 30 days' AS time_window, 'Target <=2%' AS target_threshold, 'QA Director / LiveOps QA Lead' AS owner_role, 'Core release outcome metric; used in Go/No-Go and postmortems' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R1' AS kpi_id, 'Hands-on Testing Time % per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Time Use' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, "Percentage of each QA engineer's time spent on hands-on testing activities." AS description, 'Time tracking / manual logs' AS data_sources, 'Hands-On hours per QA / total logged hours per QA.' AS calculation, 'Per QA / POD / QA Group' AS granularity, 'Weekly, per sprint, per quarter' AS time_window, 'Target 75% Hands-On per QA; deviations require context.' AS target_threshold, 'QA Manager / POD QA Lead' AS owner_role, 'Table with conditional formatting; filter by QA Group (Dev vs Amber/GSQA).' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R2' AS kpi_id, 'Non Hands-on Time % per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Time Use' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, "Percentage of each QA engineer's time spent on non hands-on activities (test design, meetings, training, pre-mastering)." AS description, 'Time tracking / manual logs' AS data_sources, 'Non Hands-On hours per QA / total logged hours per QA.' AS calculation, 'Per QA / POD / QA Group' AS granularity, 'Weekly, per sprint, per quarter' AS time_window, 'Target around 25% Non Hands-On per QA.' AS target_threshold, 'QA Manager / POD QA Lead' AS owner_role, 'Used together with R1 as 100% stacked bar per QA.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R3' AS kpi_id, 'Hands-on Hours by Activity per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Breakdown' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Hands-on hours per QA across activity types (test execution, regression, playtest, live testing, destructive, performance, etc.).' AS description, 'Time tracking / manual logs' AS data_sources, 'Sum of hands-on hours per QA per activity category.' AS calculation, 'Per QA / POD / activity' AS granularity, 'Per sprint, per quarter' AS time_window, 'No strict target; used to align focus with priorities.' AS target_threshold, 'QA Manager' AS owner_role, 'Stacked bars; aggregated view can be used for POD‑level planning.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R4' AS kpi_id, 'Non Hands-on Hours by Activity per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Breakdown' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Non hands-on hours per QA across activities (test case creation, meetings, training, pre-mastering).' AS description, 'Time tracking / manual logs' AS data_sources, 'Sum of non hands-on hours per QA per activity category.' AS calculation, 'Per QA / POD / activity' AS granularity, 'Per sprint, per quarter' AS time_window, 'Identify people overloaded with meetings / coordination.' AS target_threshold, 'QA Manager' AS owner_role, 'Stacked bar; use filters per POD or QA Group.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R5' AS kpi_id, 'Deviation from 75/25 Hands-on Mix per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Hands-on vs Non Hands-on' AS subsection, 'Focus / Deviation' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Degree to which each QA engineer diverges from the target 75% hands-on / 25% non hands-on split.' AS description, 'Time tracking / manual logs' AS data_sources, 'Hands-On % - 75% and Non Hands-On % - 25% per QA.' AS calculation, 'Per QA' AS granularity, 'Per sprint, per quarter' AS time_window, '+/-10 percentage points used as soft threshold.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar chart deviation; helps balance focus and responsibilities.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R6' AS kpi_id, 'Test Cases Executed per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Throughput & Quality' AS subsection, 'Throughput' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Number of test cases executed by each QA engineer.' AS description, 'TestRail' AS data_sources, 'For runs assigned to the QA: SUM(passed + failed + blocked + retest).' AS calculation, 'Per QA / sprint / milestone' AS granularity, 'Per sprint, per release' AS time_window, 'Used for capacity planning; not a ranking metric by itself.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Histogram or bar per QA; separate Dev QA vs Amber/GSQA.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R7' AS kpi_id, 'Pass Rate per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Throughput & Quality' AS subsection, 'Quality' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Pass rate of test cases executed by each QA engineer.' AS description, 'TestRail' AS data_sources, 'SUM(passed) / SUM(passed + failed + blocked + retest) for each QA.' AS calculation, 'Per QA / sprint / release' AS granularity, 'Per sprint, per release' AS time_window, 'Interpreted with caution; depends on type of work executed.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Used alongside R8 and R13, not in isolation.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R8' AS kpi_id, 'Fail Rate per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Throughput & Quality' AS subsection, 'Quality' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Percentage of executed test cases that failed for each QA engineer.' AS description, 'TestRail' AS data_sources, 'SUM(failed) / SUM(passed + failed + blocked + retest) for each QA.' AS calculation, 'Per QA / sprint / release' AS granularity, 'Per sprint, per release' AS time_window, 'Higher fail rate can indicate testing of riskier features.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Scatter plot vs R6 to see who works on most defect‑prone areas.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R9' AS kpi_id, 'Average Test Run Duration per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Throughput & Quality' AS subsection, 'Process / Time' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Average duration of runs executed by each QA engineer.' AS description, 'TestRail' AS data_sources, 'Average HOURS between created_on and completed_on for completed runs owned by each QA.' AS calculation, 'Per QA / sprint / suite' AS granularity, 'Rolling 4 weeks; per sprint' AS time_window, 'Identify extreme values for coaching and planning.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Box plots per QA and per suite type.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R10' AS kpi_id, 'Test Cases per Hour per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Throughput & Quality' AS subsection, 'Efficiency' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Approximate throughput of executed test cases per hour of run time.' AS description, 'TestRail + time tracking' AS data_sources, 'Executed test cases / total run duration hours for each QA.' AS calculation, 'Per QA / sprint' AS granularity, 'Per sprint, per release' AS time_window, 'Directional only; strongly depends on complexity.' AS target_threshold, 'QA Manager' AS owner_role, 'Scatter plot: throughput vs defect yield (R13).' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R11' AS kpi_id, 'Defects Reported per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Defect Volume & Yield' AS subsection, 'Volume' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Number of Jira defects created where the reporter is a specific QA engineer.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues with reporter = QA and created in period.' AS calculation, 'Per QA / sprint / release' AS granularity, 'Per sprint, per release' AS time_window, 'Used to understand distribution of defect discovery.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Bar chart per QA; separate Dev QA vs Amber/GSQA.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R12' AS kpi_id, 'High/Critical Defects Reported per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Defect Volume & Yield' AS subsection, 'Risk / Volume' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Number of high severity defects raised by each QA engineer.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues where reporter = QA AND priority in ("Blocker","Critical","High").' AS calculation, 'Per QA / sprint / release' AS granularity, 'Per sprint, per release' AS time_window, 'Highlights focus on high‑impact issues.' AS target_threshold, 'POD QA Lead' AS owner_role, 'Stacked bar by severity; used alongside R11.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R13' AS kpi_id, 'Defect Yield per QA (Defects per 100 Executed Tests)' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Defect Volume & Yield' AS subsection, 'Quality Yield' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Ratio of defects logged by each QA relative to executed test cases.' AS description, 'Jira + TestRail' AS data_sources, '(Defects reported by QA / Test cases executed by QA) * 100.' AS calculation, 'Per QA / sprint / release' AS granularity, 'Per sprint, per release' AS time_window, 'Interpret relative to feature risk and assignment.' AS target_threshold, 'QA Manager' AS owner_role, 'Scatter plot vs R10 or vs complexity measure.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R14' AS kpi_id, 'Reopen Rate for Defects Reported by QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Defect Quality per QA' AS subsection, 'Quality' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Percentage of defects originally reported by a QA that were reopened after closure.' AS description, 'Jira' AS data_sources, 'For issues with reporter = QA, reopened defects / closed defects.' AS calculation, 'Per QA / POD' AS granularity, 'Rolling 3–6 months' AS time_window, 'Lower is better; high values may indicate unclear repro or acceptance criteria.' AS target_threshold, 'QA Manager' AS owner_role, 'Trend per QA; aggregated anonymised views for broader sharing.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R15' AS kpi_id, 'Bug Report Completeness per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Quality & Reporting' AS subsection, 'OS / Quality' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, "Percentage of a QA's bug reports that meet the reproducibility standard (screens, logs, steps, build info)." AS description, 'Jira' AS data_sources, 'Complete bugs reported by QA / total bugs reported by QA.' AS calculation, 'Per QA / POD' AS granularity, 'Weekly, per release' AS time_window, 'High expectation: >99% per QA.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar chart per QA; training focus for lower values.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R16' AS kpi_id, 'Bug Rejection Rate per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Quality & Reporting' AS subsection, 'OS / Quality' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, "Percentage of a QA's reported bugs that are rejected as Not a Bug / Won't Fix / Duplicate." AS description, 'Jira' AS data_sources, 'Rejected bugs for QA / total bugs closed for QA.' AS calculation, 'Per QA / sprint / release' AS granularity, 'Weekly and per release' AS time_window, 'Expectation <5% for most QAs.' AS target_threshold, 'QA Manager' AS owner_role, 'Used carefully in 1:1s; combine with R15.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R17' AS kpi_id, 'Severity Assignment Accuracy per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Quality & Reporting' AS subsection, 'OS / Quality' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Accuracy of initial severity assigned by QA compared to final agreed severity.' AS description, 'Jira' AS data_sources, 'Correct initial severity assignments / total bugs reported by QA.' AS calculation, 'Per QA / POD' AS granularity, 'Weekly and per release' AS time_window, 'High expectation: near 100% for experienced QAs.' AS target_threshold, 'QA Manager' AS owner_role, 'Bar chart per QA; help align severity guidelines with reality.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R18' AS kpi_id, 'Bug Reporting Lead Time per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Quality & Reporting' AS subsection, 'OS / Time' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Average time each QA takes from observing an issue to logging the Jira defect.' AS description, 'Time tracking + Jira' AS data_sources, 'Average minutes from detection marker to bug creation.' AS calculation, 'Per QA / POD' AS granularity, 'Daily and per sprint' AS time_window, 'Expectation: very low, especially during focused testing sessions.' AS target_threshold, 'QA Manager' AS owner_role, 'Used primarily for OS coaching; approximate at first via manual logging.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R19' AS kpi_id, 'Time to Flag per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Quality & Reporting' AS subsection, 'OS / Communication' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Time from detecting a critical risk/blocker to first visible escalation/flag in communication channels.' AS description, 'Time tracking + comms tools' AS data_sources, 'Average minutes per QA from detection to flag.' AS calculation, 'Per QA / POD' AS granularity, 'Daily' AS time_window, 'Expectation: escalate within same testing session.' AS target_threshold, 'QA Manager / Production' AS owner_role, 'Supports postmortems when issues were flagged late.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R20' AS kpi_id, 'Response Time SLA per QA' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Quality & Reporting' AS subsection, 'OS / Communication' AS kpi_type, 'Dev QA or External QA – per individual' AS qa_group_scope, 'Average time for each QA to acknowledge urgent vs general requests in comms channels.' AS description, 'Comms tools + time tracking' AS data_sources, 'Separate averages for urgent and general messages per QA.' AS calculation, 'Per QA / POD' AS granularity, 'Weekly' AS time_window, 'Expect <10 minutes for urgent, <30 minutes for general.' AS target_threshold, 'QA Manager' AS owner_role, 'Used in conjunction with team‑level P42; not exposed publicly per person.' AS notes_looker_usage, 'manual' AS automation
UNION ALL
SELECT 'R21' AS kpi_id, 'Bugs Assigned per Developer' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Load & Flow per Developer' AS subsection, 'Workload / Volume' AS kpi_type, 'N/A – developer metric' AS qa_group_scope, 'Number of defect tickets assigned to each developer.' AS description, 'Jira' AS data_sources, 'COUNT of Bug issues where assignee = developer and created in period or currently assigned.' AS calculation, 'Per developer / POD' AS granularity, 'Per sprint, per month' AS time_window, 'No target; used to ensure fair distribution and to spot overload.' AS target_threshold, 'Engineering Manager' AS owner_role, 'Table by developer; combine with R22 and R23.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R22' AS kpi_id, 'Average Time to Resolution per Developer' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Load & Flow per Developer' AS subsection, 'Flow / SLA' AS kpi_type, 'N/A – developer metric' AS qa_group_scope, 'Average time developers take to resolve bugs assigned to them.' AS description, 'Jira' AS data_sources, 'Average DAYS between created and resolutiondate for bugs resolved by each developer.' AS calculation, 'Per developer / POD' AS granularity, 'Rolling 3–6 months' AS time_window, 'Context dependent; used for coaching and support.' AS target_threshold, 'Engineering Manager' AS owner_role, 'Box plot by team; never shared outside eng leadership.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R23' AS kpi_id, 'Reopen Rate per Developer' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Bug Load & Flow per Developer' AS subsection, 'Quality' AS kpi_type, 'N/A – developer metric' AS qa_group_scope, 'Percentage of bugs fixed by a developer that were later reopened.' AS description, 'Jira' AS data_sources, 'Reopened bugs / total bugs resolved by that developer.' AS calculation, 'Per developer / POD' AS granularity, 'Rolling 3–6 months' AS time_window, 'Lower is better; high values indicate need for deeper testing or design review.' AS target_threshold, 'Engineering Manager' AS owner_role, 'Trend chart; used in team reviews.' AS notes_looker_usage, 'computed' AS automation
UNION ALL
SELECT 'R24' AS kpi_id, 'QA Capacity vs Expectation per POD' AS kpi_name, 'private' AS privacy_level, NULL AS section, 'Capacity vs Expectations' AS subsection, 'Capacity' AS kpi_type, 'Dev QA and External QA – per POD' AS qa_group_scope, 'Comparison of actual QA hours (Dev vs External) vs expected hours from OS expectations for each POD.' AS description, 'Time tracking + OS Expectations sheet' AS data_sources, 'Actual hours / expected hours, reported as % and variance.' AS calculation, 'Per POD / QA Group / site' AS granularity, 'Per sprint, per month, per quarter' AS time_window, 'Identify overloaded or underutilised PODs; target around 100%.' AS target_threshold, 'QA Director / Production' AS owner_role, 'Variance bar or waterfall chart; basis for staffing and vendor decisions.' AS notes_looker_usage, 'manual' AS automation
;

-- -----------------------------
-- Latest-state helper views
-- -----------------------------
CREATE OR REPLACE VIEW `qa_metrics.jira_issues_latest` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY issue_key ORDER BY updated DESC, _ingested_at DESC) AS rn
  FROM `qa_metrics.jira_issues_v2`
)
WHERE rn = 1;

CREATE OR REPLACE VIEW `qa_metrics.testrail_runs_latest` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY _ingested_at DESC) AS rn
  FROM `qa_metrics.testrail_runs`
)
WHERE rn = 1;

CREATE OR REPLACE VIEW `qa_metrics.bugsnag_errors_latest` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY project_id, error_id ORDER BY last_seen DESC, _ingested_at DESC) AS rn
  FROM `qa_metrics.bugsnag_errors`
)
WHERE rn = 1;

-- -----------------------------
-- Jira status changes (one row per status transition)
-- -----------------------------
CREATE OR REPLACE VIEW `qa_metrics.jira_status_changes` AS
SELECT
  c.issue_key,
  c.history_id,
  c.history_created AS changed_at,
  JSON_VALUE(item, '$.fromString') AS from_status,
  JSON_VALUE(item, '$.toString') AS to_status
FROM `qa_metrics.jira_changelog_v2` c,
UNNEST(JSON_EXTRACT_ARRAY(c.items_json)) AS item
WHERE JSON_VALUE(item, '$.field') = 'status';

-- -----------------------------
-- LookML helper objects (explicit definitions)
-- -----------------------------

CREATE OR REPLACE VIEW `qa_metrics.jira_bug_events_daily` AS
WITH bug_base AS (
  SELECT
    issue_key,
    DATE(created) AS created_date,
    COALESCE(NULLIF(TRIM(priority), ''), 'Unspecified') AS priority_label,
    COALESCE(NULLIF(TRIM(severity), ''),
      CASE
        WHEN REGEXP_CONTAINS(LOWER(COALESCE(priority, '')), r'(blocker|critical|highest|p0|sev[\s_-]*0|s0)') THEN 'Critical'
        WHEN REGEXP_CONTAINS(LOWER(COALESCE(priority, '')), r'(high|p1|sev[\s_-]*1|s1)') THEN 'High'
        WHEN REGEXP_CONTAINS(LOWER(COALESCE(priority, '')), r'(medium|normal|p2|sev[\s_-]*2|s2)') THEN 'Medium'
        WHEN REGEXP_CONTAINS(LOWER(COALESCE(priority, '')), r'(low|lowest|minor|trivial|p3|p4|sev[\s_-]*3|s3|sev[\s_-]*4|s4)') THEN 'Low'
        ELSE 'Unspecified'
      END
    ) AS severity_label,
    COALESCE(NULLIF(TRIM(team), ''), 'Unassigned') AS pod
  FROM `qa_metrics.jira_issues_latest`
  WHERE LOWER(issue_type) = 'bug'
),
status_events AS (
  SELECT
    sc.issue_key,
    DATE(sc.changed_at) AS event_date,
    CASE
      WHEN LOWER(TRIM(COALESCE(sc.from_status, ''))) IN ('resolved', 'closed', 'verified', 'done')
       AND LOWER(TRIM(COALESCE(sc.to_status, ''))) IN ('open', 'backlog', 'to do', 'in progress', 'reopened', 'ready for qa', 'ready for test', 'qa testing', 'testing', 'in review', 'selected for development') THEN 'reopened'
      WHEN LOWER(TRIM(COALESCE(sc.to_status, ''))) IN ('resolved', 'closed', 'verified', 'done') THEN 'fixed'
      ELSE NULL
    END AS event_type
  FROM `qa_metrics.jira_status_changes` sc
),
created_events AS (
  SELECT
    issue_key,
    created_date AS event_date,
    'created' AS event_type
  FROM bug_base
)
SELECT
  e.event_date,
  e.event_type,
  b.priority_label,
  b.severity_label,
  b.pod,
  COUNT(DISTINCT e.issue_key) AS bugs_count
FROM (
  SELECT * FROM created_events
  UNION ALL
  SELECT * FROM status_events WHERE event_type IS NOT NULL
) e
JOIN bug_base b USING (issue_key)
WHERE e.event_date IS NOT NULL
GROUP BY 1,2,3,4,5;

CREATE OR REPLACE VIEW `qa_metrics.jira_fix_fail_rate_daily` AS
WITH fixed AS (
  SELECT
    DATE(changed_at) AS event_date,
    COUNT(DISTINCT issue_key) AS fixed_count
  FROM `qa_metrics.jira_status_changes`
  WHERE LOWER(TRIM(COALESCE(to_status, ''))) IN ('resolved', 'closed', 'verified', 'done')
  GROUP BY 1
),
reopened AS (
  SELECT
    DATE(changed_at) AS event_date,
    COUNT(DISTINCT issue_key) AS reopened_count
  FROM `qa_metrics.jira_status_changes`
  WHERE LOWER(TRIM(COALESCE(from_status, ''))) IN ('resolved', 'closed', 'verified', 'done')
    AND LOWER(TRIM(COALESCE(to_status, ''))) IN ('open', 'backlog', 'to do', 'in progress', 'reopened', 'ready for qa', 'ready for test', 'qa testing', 'testing', 'in review', 'selected for development')
  GROUP BY 1
)
SELECT
  COALESCE(f.event_date, r.event_date) AS event_date,
  COALESCE(f.fixed_count, 0) AS fixed_count,
  COALESCE(r.reopened_count, 0) AS reopened_count
FROM fixed f
FULL OUTER JOIN reopened r
  ON f.event_date = r.event_date;

CREATE OR REPLACE VIEW `qa_metrics.jira_mttr_fixed_daily` AS
WITH fixed_cohort AS (
  SELECT
    sc.issue_key,
    MIN(sc.changed_at) AS fixed_at
  FROM `qa_metrics.jira_status_changes` sc
  WHERE sc.to_status IN ('Resolved', 'Closed', 'Verified')
  GROUP BY 1
),
bugs AS (
  SELECT
    issue_key,
    created
  FROM `qa_metrics.jira_issues_latest`
  WHERE LOWER(issue_type) = 'bug'
    AND created IS NOT NULL
)
SELECT
  DATE(fc.fixed_at) AS event_date,
  AVG(TIMESTAMP_DIFF(fc.fixed_at, b.created, SECOND) / 3600.0) AS mttr_hours
FROM fixed_cohort fc
JOIN bugs b
  ON b.issue_key = fc.issue_key
WHERE fc.fixed_at >= b.created
GROUP BY 1;

CREATE OR REPLACE VIEW `qa_metrics.jira_mttr_claimed_fixed_daily` AS
WITH claimed_fixed_events AS (
  SELECT
    sc.issue_key,
    MIN(sc.changed_at) AS claimed_fixed_at
  FROM `qa_metrics.jira_status_changes` sc
  WHERE sc.to_status IN ('Resolved', 'Closed', 'Verified')
  GROUP BY 1
),
bugs AS (
  SELECT
    issue_key,
    created
  FROM `qa_metrics.jira_issues_latest`
  WHERE LOWER(issue_type) = 'bug'
    AND created IS NOT NULL
)
SELECT
  DATE(cfe.claimed_fixed_at) AS event_date,
  AVG(TIMESTAMP_DIFF(cfe.claimed_fixed_at, b.created, SECOND) / 3600.0) AS avg_mttr_hours,
  COUNT(DISTINCT cfe.issue_key) AS issues_count
FROM claimed_fixed_events cfe
JOIN bugs b
  ON b.issue_key = cfe.issue_key
WHERE cfe.claimed_fixed_at >= b.created
GROUP BY 1;

CREATE OR REPLACE VIEW `qa_metrics.jira_active_bug_count_daily` AS
WITH bug_lifecycle AS (
  SELECT
    ji.issue_key,
    DATE(ji.created) AS created_date,
    DATE(MIN(sc.changed_at)) AS fixed_date
  FROM `qa_metrics.jira_issues_latest` ji
  LEFT JOIN `qa_metrics.jira_status_changes` sc
    ON sc.issue_key = ji.issue_key
   AND sc.to_status IN ('Resolved', 'Closed', 'Verified')
  WHERE LOWER(ji.issue_type) = 'bug'
    AND ji.created IS NOT NULL
  GROUP BY 1,2
),
date_spine AS (
  SELECT metric_date
  FROM UNNEST(
    GENERATE_DATE_ARRAY(
      (SELECT MIN(created_date) FROM bug_lifecycle),
      CURRENT_DATE(),
      INTERVAL 1 DAY
    )
  ) AS metric_date
)
SELECT
  d.metric_date,
  COUNTIF(
    b.created_date <= d.metric_date
    AND (b.fixed_date IS NULL OR b.fixed_date > d.metric_date)
  ) AS active_bug_count
FROM date_spine d
CROSS JOIN bug_lifecycle b
GROUP BY 1;

CREATE OR REPLACE VIEW `qa_metrics.testrail_bvt_latest` AS
SELECT
  run_id,
  name,
  completed_on,
  SAFE_DIVIDE(
    CAST(passed_count AS FLOAT64),
    NULLIF(CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64), 0.0)
  ) AS pass_rate_calc
FROM `qa_metrics.testrail_runs_latest`
WHERE REGEXP_CONTAINS(UPPER(COALESCE(name, '')), r'\bBVT\b')
  AND completed_on IS NOT NULL;

CREATE TABLE IF NOT EXISTS `qa_metrics.build_size_manual` (
  metric_date DATE,
  platform STRING,
  environment STRING,
  build_version STRING,
  build_size_mb FLOAT64,
  _updated_at TIMESTAMP
)
PARTITION BY metric_date
CLUSTER BY platform, environment;

CREATE TABLE IF NOT EXISTS `qa_metrics.gamebench_daily_metrics` (
  metric_date DATE,
  environment STRING,
  platform STRING,
  app_package STRING,
  app_version STRING,
  device_model STRING,
  device_manufacturer STRING,
  os_version STRING,
  gpu_model STRING,
  sessions INT64,
  median_fps FLOAT64,
  fps_stability_pct FLOAT64,
  fps_stability_index FLOAT64,
  cpu_avg_pct FLOAT64,
  cpu_max_pct FLOAT64,
  memory_avg_mb FLOAT64,
  memory_max_mb FLOAT64,
  current_avg_ma FLOAT64,
  _updated_at TIMESTAMP
)
PARTITION BY metric_date
CLUSTER BY environment, platform, app_version;

CREATE OR REPLACE VIEW `qa_metrics.gamebench_sessions_latest` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY time_pushed DESC, _ingested_at DESC) AS rn
  FROM `qa_metrics.gamebench_sessions_v1`
)
WHERE rn = 1;

-- -----------------------------
-- KPI Facts View (used by Looker)
-- -----------------------------
CREATE OR REPLACE VIEW `qa_metrics.qa_kpi_facts` AS
WITH
config AS (
  SELECT
    ['Closed','Verified','Resolved'] AS done_statuses,
    ['Blocker','Critical','P0','P1','High'] AS high_priorities,
    ['Duplicate','Rejected','Invalid','Not a Bug','Cannot Reproduce','Won\'t Fix','Won\'t Do','Incomplete','As Designed'] AS rejected_resolutions,
    ['NMI','Not Meaningful','No Merge','No-Merge','Not Meaningful Issue'] AS nmi_resolutions,
    72 AS sla_hours_critical,
    168 AS sla_hours_high
),
jira AS (
  SELECT
    *,
    NULLIF(TRIM(team), '') AS pod,
    NULLIF(TRIM(SPLIT(components, ',')[SAFE_OFFSET(0)]), '') AS feature,
    NULLIF(TRIM(SPLIT(fix_versions, ',')[SAFE_OFFSET(0)]), '') AS release,
    NULLIF(TRIM(SPLIT(sprint, ',')[SAFE_OFFSET(0)]), '') AS sprint_norm,
    CASE
      WHEN priority IN ('Blocker','Critical','P0') THEN 'Critical'
      WHEN priority IN ('High','P1') THEN 'High'
      WHEN priority IN ('Medium','P2') THEN 'Medium'
      WHEN priority IN ('Low','P3','Minor','Trivial') THEN 'Low'
      ELSE priority
    END AS severity_norm,
    CASE
      WHEN resolution IN UNNEST((SELECT rejected_resolutions FROM config)) THEN 'rejected'
      WHEN resolution IN UNNEST((SELECT nmi_resolutions FROM config)) THEN 'nmi'
      WHEN resolution IS NULL THEN NULL
      ELSE 'accepted'
    END AS resolution_class
  FROM `qa_metrics.jira_issues_latest`
),
jira_bugs AS (
  SELECT *
  FROM jira
  WHERE LOWER(issue_type) = 'bug'
),
jira_done_story_points AS (
  SELECT *
  FROM jira
  WHERE story_points IS NOT NULL
    AND resolutiondate IS NOT NULL
    AND LOWER(issue_type) IN ('story','task','improvement')
),
status_changes AS (
  SELECT * FROM `qa_metrics.jira_status_changes`
),
triage_times AS (
  SELECT
    issue_key,
    MIN(changed_at) AS triaged_at
  FROM status_changes
  WHERE to_status NOT IN ('Open','Backlog')
  GROUP BY issue_key
),
reopen_events AS (
  SELECT
    sc.issue_key,
    sc.changed_at AS reopened_at,
    sc.from_status,
    sc.to_status
  FROM status_changes sc
  WHERE sc.to_status = 'Reopened'
),
resolved_events AS (
  SELECT issue_key, changed_at AS resolved_at
  FROM status_changes
  WHERE to_status = 'Resolved'
),
verified_events AS (
  SELECT issue_key, changed_at AS verified_at
  FROM status_changes
  WHERE to_status IN ('Verified','Closed')
),
fix_verification AS (
  SELECT
    r.issue_key,
    r.resolved_at,
    (
      SELECT MIN(v.verified_at)
      FROM verified_events v
      WHERE v.issue_key = r.issue_key
        AND v.verified_at >= r.resolved_at
    ) AS verified_at
  FROM resolved_events r
),
testrail_runs AS (
  SELECT
    rl.*,
    m.pod,
    m.feature,
    m.release,
    NULLIF(TRIM(SPLIT(rl.name, ' ')[SAFE_OFFSET(0)]), '') AS sprint_norm  -- best-effort; adjust if you encode sprint in run name
  FROM `qa_metrics.testrail_runs_latest` rl
  LEFT JOIN `qa_metrics.source_project_mapping` m
    ON m.source = 'testrail' AND m.source_project_id = CAST(rl.project_id AS STRING)
),
testrail_results AS (
  SELECT
    r.*,
    m.pod,
    m.feature,
    m.release,
    CASE
      WHEN status_id = 1 THEN 'passed'
      WHEN status_id = 2 THEN 'blocked'
      WHEN status_id = 4 THEN 'retest'
      WHEN status_id = 5 THEN 'failed'
      ELSE 'other'
    END AS status_bucket
  FROM `qa_metrics.testrail_results` r
  LEFT JOIN `qa_metrics.source_project_mapping` m
    ON m.source = 'testrail' AND m.source_project_id = CAST(r.project_id AS STRING)
),
bugsnag AS (
  SELECT
    bl.*,
    m.pod,
    m.feature,
    m.release,
    CASE
      WHEN LOWER(bl.severity) = 'error' THEN 'High'
      WHEN LOWER(bl.severity) = 'warning' THEN 'Medium'
      WHEN LOWER(bl.severity) = 'info' THEN 'Low'
      ELSE bl.severity
    END AS severity_norm
  FROM `qa_metrics.bugsnag_errors_latest` bl
  LEFT JOIN `qa_metrics.source_project_mapping` m
    ON m.source = 'bugsnag' AND m.source_project_id = CAST(bl.project_id AS STRING)
),
qa_xwalk AS (
  SELECT * FROM `qa_metrics.qa_user_crosswalk` WHERE is_active IS TRUE OR is_active IS NULL
),
jira_with_qa AS (
  SELECT
    j.*,
    COALESCE(x.canonical_qa_user, j.reporter) AS qa_user_norm
  FROM jira_bugs j
  LEFT JOIN qa_xwalk x
    ON x.jira_account_id = j.reporter_account_id
),
testrail_results_with_qa AS (
  SELECT
    tr.*,
    COALESCE(x.canonical_qa_user, CAST(tr.created_by AS STRING)) AS qa_user_norm
  FROM testrail_results tr
  LEFT JOIN qa_xwalk x
    ON x.testrail_user_id = tr.created_by
),
testrail_runs_with_qa AS (
  SELECT
    tr.*,
    COALESCE(x.canonical_qa_user, CAST(COALESCE(tr.assignedto_id, tr.created_by) AS STRING)) AS qa_user_norm
  FROM testrail_runs tr
  LEFT JOIN qa_xwalk x
    ON x.testrail_user_id = COALESCE(tr.assignedto_id, tr.created_by)
),
-- Completeness heuristic: consider "complete" if description is present and has components + priority
bug_completeness AS (
  SELECT
    issue_key,
    IF(
      (description_plain IS NOT NULL AND LENGTH(description_plain) >= 80)
      AND (components IS NOT NULL AND LENGTH(components) > 0)
      AND (priority IS NOT NULL AND LENGTH(priority) > 0),
      1, 0
    ) AS is_complete
  FROM jira_bugs
)

SELECT * FROM (
  -- ---------------------------------------
  -- P1 Defects Created (count)
  -- ---------------------------------------
  SELECT
    'P1' AS kpi_id,
    'Defects Created' AS kpi_name,
    'public' AS privacy_level,
    DATE(created) AS metric_date,
    pod,
    feature,
    release,
    sprint_norm AS sprint,
    NULL AS qa_user,
    NULL AS developer_user,
    severity_norm AS severity,
    1.0 AS numerator,
    NULL AS denominator,
    NULL AS value,
    'count' AS unit,
    'jira' AS source
  FROM jira_bugs
  WHERE created IS NOT NULL

  UNION ALL

  -- P2 Defects Closed (count)
  SELECT
    'P2',
    'Defects Closed',
    'public',
    DATE(resolutiondate) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NOT NULL

  UNION ALL

  -- P3 Defects Reopened (count of reopened transitions from done -> Reopened)
  SELECT
    'P3',
    'Defects Reopened',
    'public',
    DATE(r.reopened_at) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'jira'
  FROM reopen_events r
  JOIN jira_bugs j USING(issue_key)
  WHERE r.from_status IN UNNEST((SELECT done_statuses FROM config))

  UNION ALL

  -- P4 Defect Reopen Rate = reopened / closed
  -- numerator rows: reopened events
  SELECT
    'P4',
    'Defect Reopen Rate',
    'public',
    DATE_TRUNC(DATE(r.reopened_at), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    1.0 AS numerator,
    0.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM reopen_events r
  JOIN jira_bugs j USING(issue_key)
  WHERE r.from_status IN UNNEST((SELECT done_statuses FROM config))

  UNION ALL

  -- denominator rows: closed bugs
  SELECT
    'P4',
    'Defect Reopen Rate',
    'public',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    0.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NOT NULL

  UNION ALL

  -- P5 Open Defect Backlog (snapshot)
  SELECT
    'P5',
    'Open Defect Backlog',
    'public',
    CURRENT_DATE() AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    1.0 AS numerator,
    NULL,
    NULL,
    'count',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NULL AND status NOT IN UNNEST((SELECT done_statuses FROM config))

  UNION ALL

  -- P6 Open Critical & High Defects (snapshot)
  SELECT
    'P6',
    'Open Critical & High Defects',
    'public',
    CURRENT_DATE() AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NULL
    AND status NOT IN UNNEST((SELECT done_statuses FROM config))
    AND priority IN UNNEST((SELECT high_priorities FROM config))

  UNION ALL

  -- P7 Average Age of Open Defects (days) (snapshot)
  SELECT
    'P7',
    'Average Age of Open Defects',
    'public',
    CURRENT_DATE() AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    CAST(DATE_DIFF(CURRENT_DATE(), DATE(created), DAY) AS FLOAT64) AS numerator,
    1.0 AS denominator,
    NULL,
    'days',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL
    AND resolutiondate IS NULL
    AND status NOT IN UNNEST((SELECT done_statuses FROM config))

  UNION ALL

  -- P8 Defect Density (Bugs per 100 Story Points)
  -- numerator: each bug contributes 100
  SELECT
    'P8',
    'Defect Density (Bugs per 100 Story Points)',
    'public',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    100.0 AS numerator,
    0.0 AS denominator,
    NULL,
    'per_100_sp',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL AND sprint_norm IS NOT NULL

  UNION ALL

  -- denominator: completed story points
  SELECT
    'P8',
    'Defect Density (Bugs per 100 Story Points)',
    'public',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL AS severity,
    0.0 AS numerator,
    CAST(story_points AS FLOAT64) AS denominator,
    NULL,
    'per_100_sp',
    'jira'
  FROM jira_done_story_points
  WHERE sprint_norm IS NOT NULL

  UNION ALL

  -- P9 Time to Triage (hours)
  SELECT
    'P9',
    'Time to Triage',
    'public',
    DATE_TRUNC(DATE(j.created), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    CAST(TIMESTAMP_DIFF(t.triaged_at, j.created, SECOND) AS FLOAT64) / 3600.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'hours',
    'jira'
  FROM jira_bugs j
  JOIN triage_times t USING(issue_key)
  WHERE j.created IS NOT NULL AND t.triaged_at IS NOT NULL

  UNION ALL

  -- P10 Time to Resolution (MTTR) (hours)
  SELECT
    'P10',
    'Time to Resolution (MTTR)',
    'public',
    DATE_TRUNC(DATE(j.resolutiondate), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    CAST(TIMESTAMP_DIFF(j.resolutiondate, j.created, SECOND) AS FLOAT64) / 3600.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'hours',
    'jira'
  FROM jira_bugs j
  WHERE j.created IS NOT NULL AND j.resolutiondate IS NOT NULL

  UNION ALL

  -- P11 SLA Compliance for Critical/High Defects
  SELECT
    'P11',
    'SLA Compliance for Critical/High Defects',
    'public',
    DATE_TRUNC(DATE(j.resolutiondate), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    CASE
      WHEN j.priority IN ('Blocker','Critical','P0') AND TIMESTAMP_DIFF(j.resolutiondate, j.created, HOUR) <= (SELECT sla_hours_critical FROM config) THEN 1.0
      WHEN j.priority IN ('High','P1') AND TIMESTAMP_DIFF(j.resolutiondate, j.created, HOUR) <= (SELECT sla_hours_high FROM config) THEN 1.0
      WHEN j.priority IN UNNEST((SELECT high_priorities FROM config)) AND TIMESTAMP_DIFF(j.resolutiondate, j.created, HOUR) <= (SELECT sla_hours_high FROM config) THEN 1.0
      ELSE 0.0
    END AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs j
  WHERE j.created IS NOT NULL
    AND j.resolutiondate IS NOT NULL
    AND j.priority IN UNNEST((SELECT high_priorities FROM config))

  UNION ALL

  -- P12 Test Runs Executed (completed runs)
  SELECT
    'P12',
    'Test Runs Executed',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL AS severity,
    1.0,
    NULL,
    NULL,
    'count',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P13 Test Cases Executed (sum executed)
  SELECT
    'P13',
    'Test Cases Executed',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64) AS numerator,
    NULL,
    NULL,
    'count',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P14 Pass Rate
  SELECT
    'P14',
    'Pass Rate',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(passed_count AS FLOAT64) AS numerator,
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64) AS denominator,
    NULL,
    'ratio',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P15 Fail Rate
  SELECT
    'P15',
    'Fail Rate',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(failed_count AS FLOAT64) AS numerator,
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64) AS denominator,
    NULL,
    'ratio',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P16 Blocked Rate
  SELECT
    'P16',
    'Blocked Rate',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(blocked_count AS FLOAT64),
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64),
    NULL,
    'ratio',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P17 Retest Rate
  SELECT
    'P17',
    'Retest Rate',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(retest_count AS FLOAT64),
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64),
    NULL,
    'ratio',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P18 Test Coverage (Executed vs Planned)
  SELECT
    'P18',
    'Test Coverage (Executed vs Planned)',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64) AS numerator,
    CAST(passed_count + failed_count + blocked_count + retest_count + untested_count AS FLOAT64) AS denominator,
    NULL,
    'ratio',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P19 Average Test Run Duration (hours)
  SELECT
    'P19',
    'Average Test Run Duration',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    CAST(TIMESTAMP_DIFF(completed_on, created_on, SECOND) AS FLOAT64) / 3600.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'hours',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL AND created_on IS NOT NULL

  UNION ALL

  -- P20 Active Production Errors (snapshot)
  SELECT
    'P20',
    'Active Production Errors',
    'public',
    CURRENT_DATE() AS metric_date,
    pod, feature, release, NULL AS sprint,
    NULL, NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'bugsnag'
  FROM bugsnag
  WHERE LOWER(status) NOT IN ('fixed','closed','resolved')

  UNION ALL

  -- P21 High/Critical Active Errors (snapshot) - treat Bugsnag 'error' as high
  SELECT
    'P21',
    'High/Critical Active Errors',
    'public',
    CURRENT_DATE() AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'bugsnag'
  FROM bugsnag
  WHERE LOWER(status) NOT IN ('fixed','closed','resolved')
    AND LOWER(severity) = 'error'

  UNION ALL

  -- P22 New Production Errors (unique new errors by first_seen)
  SELECT
    'P22',
    'New Production Errors',
    'public',
    DATE_TRUNC(DATE(first_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'bugsnag'
  FROM bugsnag
  WHERE first_seen IS NOT NULL

  UNION ALL

  -- P23 Total Error Events (proxy: events count on latest snapshot, bucketed by last_seen week)
  SELECT
    'P23',
    'Total Error Events (Live Incident Rate)',
    'public',
    DATE_TRUNC(DATE(last_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    CAST(events AS FLOAT64) AS numerator,
    NULL,
    NULL,
    'count',
    'bugsnag'
  FROM bugsnag
  WHERE last_seen IS NOT NULL

  UNION ALL

  -- P24 Users Impacted by Errors (proxy: users count on latest snapshot, bucketed by last_seen week)
  SELECT
    'P24',
    'Users Impacted by Errors',
    'public',
    DATE_TRUNC(DATE(last_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    CAST(users AS FLOAT64),
    NULL,
    NULL,
    'count',
    'bugsnag'
  FROM bugsnag
  WHERE last_seen IS NOT NULL

  UNION ALL

  -- P25 Average Error Lifetime (hours)
  SELECT
    'P25',
    'Average Error Lifetime',
    'public',
    DATE_TRUNC(DATE(last_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    CAST(TIMESTAMP_DIFF(last_seen, first_seen, SECOND) AS FLOAT64) / 3600.0,
    1.0,
    NULL,
    'hours',
    'bugsnag'
  FROM bugsnag
  WHERE first_seen IS NOT NULL AND last_seen IS NOT NULL

  UNION ALL

  -- P26 Defects per 100 Test Cases Executed
  -- numerator: each bug contributes 100
  SELECT
    'P26',
    'Defects per 100 Test Cases Executed',
    'public',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    100.0 AS numerator,
    0.0 AS denominator,
    NULL,
    'per_100_tests',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL

  UNION ALL

  -- denominator: executed tests (from completed runs)
  SELECT
    'P26',
    'Defects per 100 Test Cases Executed',
    'public',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    0.0 AS numerator,
    CAST(passed_count + failed_count + blocked_count + retest_count AS FLOAT64) AS denominator,
    NULL,
    'per_100_tests',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL

  UNION ALL

  -- P33 Bug Rejection Rate
  SELECT
    'P33',
    'Bug Rejection Rate',
    'public',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    IF(resolution_class = 'rejected', 1.0, 0.0) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NOT NULL

  UNION ALL

  -- P34 Bug Report Completeness
  SELECT
    'P34',
    'Bug Report Completeness',
    'public',
    DATE_TRUNC(DATE(j.created), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    CAST(c.is_complete AS FLOAT64) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs j
  JOIN bug_completeness c USING(issue_key)
  WHERE j.created IS NOT NULL

  UNION ALL

  -- P39 Fix Verification Cycle Time (hours): Resolved -> Verified/Closed
  SELECT
    'P39',
    'Fix Verification Cycle Time',
    'public',
    DATE_TRUNC(DATE(f.verified_at), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL, NULL,
    j.severity_norm,
    CAST(TIMESTAMP_DIFF(f.verified_at, f.resolved_at, SECOND) AS FLOAT64) / 3600.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'hours',
    'jira'
  FROM fix_verification f
  JOIN jira_bugs j USING(issue_key)
  WHERE f.resolved_at IS NOT NULL AND f.verified_at IS NOT NULL

  UNION ALL

  -- P43 Defect Acceptance Ratio (Accepted / Total Closed)
  SELECT
    'P43',
    'Defect Acceptance Ratio (DAR)',
    'public',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    IF(resolution_class = 'accepted', 1.0, 0.0) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NOT NULL

  UNION ALL

  -- P44 High Severity Defect Reporting Rate
  SELECT
    'P44',
    'High Severity Defect Reporting Rate (P0+P1)',
    'public',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    IF(priority IN UNNEST((SELECT high_priorities FROM config)), 1.0, 0.0) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL

  UNION ALL

  -- P45 NMI Rate
  SELECT
    'P45',
    'NMI Rate (No-Merge / Not Meaningful Issues)',
    'public',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    IF(resolution_class = 'nmi', 1.0, 0.0) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NOT NULL

  UNION ALL

  -- P31 Bug Escape Rate (proxy): production defects (new Bugsnag errors) / (jira bugs + production defects)
  -- production defects contribute numerator=1 & denominator=1
  SELECT
    'P31',
    'Bug Escape Rate (by severity)',
    'public',
    DATE_TRUNC(DATE(first_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    1.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'bugsnag'
  FROM bugsnag
  WHERE first_seen IS NOT NULL

  UNION ALL

  -- pre-release bugs contribute denominator only
  SELECT
    'P31',
    'Bug Escape Rate (by severity)',
    'public',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    0.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL

  UNION ALL

  -- P32 Defect Detection Efficiency (proxy): pre-release bugs / total bugs
  SELECT
    'P32',
    'Defect Detection Efficiency (DDE)',
    'public',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    severity_norm,
    1.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL

  UNION ALL

  SELECT
    'P32',
    'Defect Detection Efficiency (DDE)',
    'public',
    DATE_TRUNC(DATE(first_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    severity_norm,
    0.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'bugsnag'
  FROM bugsnag
  WHERE first_seen IS NOT NULL

  UNION ALL

  -- P46 Defect Leak Rate (Live) (same proxy as escape rate, without severity slicing)
  SELECT
    'P46',
    'Defect Leak Rate (Live)',
    'public',
    DATE_TRUNC(DATE(first_seen), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    NULL, NULL,
    NULL AS severity,
    1.0,
    1.0,
    NULL,
    'ratio',
    'bugsnag'
  FROM bugsnag
  WHERE first_seen IS NOT NULL

  UNION ALL

  SELECT
    'P46',
    'Defect Leak Rate (Live)',
    'public',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL, NULL,
    NULL,
    0.0,
    1.0,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL

  UNION ALL

  -- -------------------------------
  -- PRIVATE KPIs (Leadership only)
  -- -------------------------------

  -- R6 Test Cases Executed per QA
  SELECT
    'R6',
    'Test Cases Executed per QA',
    'private',
    DATE_TRUNC(DATE(created_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    qa_user_norm AS qa_user,
    NULL AS developer_user,
    NULL AS severity,
    1.0 AS numerator,
    NULL AS denominator,
    NULL AS value,
    'count' AS unit,
    'testrail' AS source
  FROM testrail_results_with_qa
  WHERE created_on IS NOT NULL

  UNION ALL

  -- R7 Pass Rate per QA
  SELECT
    'R7',
    'Pass Rate per QA',
    'private',
    DATE_TRUNC(DATE(created_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    qa_user_norm,
    NULL,
    NULL,
    IF(status_bucket = 'passed', 1.0, 0.0) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'testrail'
  FROM testrail_results_with_qa
  WHERE created_on IS NOT NULL

  UNION ALL

  -- R8 Fail Rate per QA
  SELECT
    'R8',
    'Fail Rate per QA',
    'private',
    DATE_TRUNC(DATE(created_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    qa_user_norm,
    NULL,
    NULL,
    IF(status_bucket = 'failed', 1.0, 0.0) AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'testrail'
  FROM testrail_results_with_qa
  WHERE created_on IS NOT NULL

  UNION ALL

  -- R9 Average Test Run Duration per QA (hours)
  SELECT
    'R9',
    'Average Test Run Duration per QA',
    'private',
    DATE_TRUNC(DATE(completed_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    qa_user_norm,
    NULL,
    NULL,
    CAST(TIMESTAMP_DIFF(completed_on, created_on, SECOND) AS FLOAT64) / 3600.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'hours',
    'testrail'
  FROM testrail_runs_with_qa
  WHERE is_completed IS TRUE AND completed_on IS NOT NULL AND created_on IS NOT NULL

  UNION ALL

  -- R11 Defects Reported per QA
  SELECT
    'R11',
    'Defects Reported per QA',
    'private',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    qa_user_norm,
    NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'jira'
  FROM jira_with_qa
  WHERE created IS NOT NULL

  UNION ALL

  -- R12 High/Critical Defects Reported per QA
  SELECT
    'R12',
    'High/Critical Defects Reported per QA',
    'private',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    qa_user_norm,
    NULL,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'jira'
  FROM jira_with_qa
  WHERE created IS NOT NULL
    AND priority IN UNNEST((SELECT high_priorities FROM config))

  UNION ALL

  -- R13 Defect Yield per QA (Defects per 100 Executed Tests)
  -- numerator: each defect contributes 100
  SELECT
    'R13',
    'Defect Yield per QA (Defects per 100 Executed Tests)',
    'private',
    DATE_TRUNC(DATE(created), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    qa_user_norm,
    NULL,
    severity_norm,
    100.0 AS numerator,
    0.0 AS denominator,
    NULL,
    'per_100_tests',
    'jira'
  FROM jira_with_qa
  WHERE created IS NOT NULL

  UNION ALL

  -- denominator: each executed test contributes 1
  SELECT
    'R13',
    'Defect Yield per QA (Defects per 100 Executed Tests)',
    'private',
    DATE_TRUNC(DATE(created_on), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, NULL,
    qa_user_norm,
    NULL,
    NULL,
    0.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'per_100_tests',
    'testrail'
  FROM testrail_results_with_qa
  WHERE created_on IS NOT NULL

  UNION ALL

  -- R14 Reopen Rate for Defects Reported by QA
  SELECT
    'R14',
    'Reopen Rate for Defects Reported by QA',
    'private',
    DATE_TRUNC(DATE(r.reopened_at), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    j.qa_user_norm,
    NULL,
    j.severity_norm,
    1.0 AS numerator,
    0.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM reopen_events r
  JOIN jira_with_qa j USING(issue_key)
  WHERE r.from_status IN UNNEST((SELECT done_statuses FROM config))

  UNION ALL

  SELECT
    'R14',
    'Reopen Rate for Defects Reported by QA',
    'private',
    DATE_TRUNC(DATE(j.resolutiondate), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    j.qa_user_norm,
    NULL,
    j.severity_norm,
    0.0 AS numerator,
    1.0 AS denominator,
    NULL,
    'ratio',
    'jira'
  FROM jira_with_qa j
  WHERE j.resolutiondate IS NOT NULL

  UNION ALL

  -- R15 Bug Report Completeness per QA
  SELECT
    'R15',
    'Bug Report Completeness per QA',
    'private',
    DATE_TRUNC(DATE(j.created), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    j.qa_user_norm,
    NULL,
    j.severity_norm,
    CAST(c.is_complete AS FLOAT64),
    1.0,
    NULL,
    'ratio',
    'jira'
  FROM jira_with_qa j
  JOIN bug_completeness c USING(issue_key)
  WHERE j.created IS NOT NULL

  UNION ALL

  -- R16 Bug Rejection Rate per QA
  SELECT
    'R16',
    'Bug Rejection Rate per QA',
    'private',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    qa_user_norm,
    NULL,
    severity_norm,
    IF(resolution_class = 'rejected', 1.0, 0.0),
    1.0,
    NULL,
    'ratio',
    'jira'
  FROM jira_with_qa
  WHERE resolutiondate IS NOT NULL

  UNION ALL

  -- R21 Bugs Assigned per Developer (open bugs snapshot)
  SELECT
    'R21',
    'Bugs Assigned per Developer',
    'private',
    CURRENT_DATE() AS metric_date,
    pod, feature, release, sprint_norm,
    NULL,
    assignee AS developer_user,
    severity_norm,
    1.0,
    NULL,
    NULL,
    'count',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NULL AND status NOT IN UNNEST((SELECT done_statuses FROM config))
    AND assignee IS NOT NULL

  UNION ALL

  -- R22 Average Time to Resolution per Developer (hours)
  SELECT
    'R22',
    'Average Time to Resolution per Developer',
    'private',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL,
    assignee,
    severity_norm,
    CAST(TIMESTAMP_DIFF(resolutiondate, created, SECOND) AS FLOAT64) / 3600.0,
    1.0,
    NULL,
    'hours',
    'jira'
  FROM jira_bugs
  WHERE created IS NOT NULL AND resolutiondate IS NOT NULL AND assignee IS NOT NULL

  UNION ALL

  -- R23 Reopen Rate per Developer
  SELECT
    'R23',
    'Reopen Rate per Developer',
    'private',
    DATE_TRUNC(DATE(r.reopened_at), WEEK(MONDAY)) AS metric_date,
    j.pod, j.feature, j.release, j.sprint_norm,
    NULL,
    j.assignee,
    j.severity_norm,
    1.0,
    0.0,
    NULL,
    'ratio',
    'jira'
  FROM reopen_events r
  JOIN jira_bugs j USING(issue_key)
  WHERE r.from_status IN UNNEST((SELECT done_statuses FROM config))
    AND j.assignee IS NOT NULL

  UNION ALL

  SELECT
    'R23',
    'Reopen Rate per Developer',
    'private',
    DATE_TRUNC(DATE(resolutiondate), WEEK(MONDAY)) AS metric_date,
    pod, feature, release, sprint_norm,
    NULL,
    assignee,
    severity_norm,
    0.0,
    1.0,
    NULL,
    'ratio',
    'jira'
  FROM jira_bugs
  WHERE resolutiondate IS NOT NULL AND assignee IS NOT NULL

)
UNION ALL
-- Manual KPI values always included (privacy enforced in Looker with sql_always_where)
SELECT
  kpi_id,
  kpi_name,
  privacy_level,
  metric_date,
  pod,
  feature,
  release,
  sprint,
  qa_user,
  developer_user,
  severity,
  numerator,
  denominator,
  value,
  unit,
  source
FROM `qa_metrics.manual_kpi_values`;

CREATE OR REPLACE VIEW `qa_metrics.qa_kpi_facts_enriched` AS
SELECT
  f.*,
  COALESCE(NULLIF(f.severity, ""), "Unspecified") AS priority_label
FROM `qa_metrics.qa_kpi_facts` f;

END;
