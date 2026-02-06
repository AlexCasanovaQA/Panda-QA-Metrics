# Panda Public model
# Generated: 2026-01-08T12:27:33.921627Z

connection: "qa-panda-metrics-exp"

include: "/views/*.view.lkml"

# Cache-busting trigger (update via scheduled query / ingesters)
datagroup: panda_ingestion_dg {
  sql_trigger: SELECT MAX(updated_at) FROM `qa-panda-metrics.qa_metrics.ingestion_state` ;;
  max_cache_age: "15 minutes"
}

# Public explores (avoid people-level fields by default)
explore: jira_issues {
  label: "Jira — Issues (Public)"
  description: "Latest Jira issues snapshot (deduped)."
}

explore: jira_issue_status_times {
  label: "Jira — Cycle Times (Public)"
  description: "Status milestone timestamps per issue (triage, resolved, reopened) for cycle-time KPIs."
}

explore: jira_issue_events {
  label: "Jira — Issue Events (Public)"
  description: "Status/field change events from Jira changelog (supports reopen + severity accuracy KPIs)."
}

explore: bugsnag_errors {
  label: "Bugsnag — Errors (Public)"
  description: "Latest Bugsnag errors snapshot (deduped)."
}

explore: testrail_runs {
  label: "TestRail — Runs (Public)"
  description: "Latest TestRail runs snapshot (deduped)."
}

explore: testrail_test_result_history {
  label: "TestRail — Result History (Public)"
  description: "Per-test first/last status + 'changed result' flag (supports Execution Result Accuracy KPI)."
}

# ------------------------------
# Manual / ops KPIs (PUBLIC-safe)
# ------------------------------
explore: qa_time_entries_public {
  label: "QA Time (Public)"
  description: "Aggregated time tracking (no person-level data)."
}

explore: exploratory_sessions_public {
  label: "Exploratory Sessions (Public)"
  description: "Aggregated exploratory session logging."
}

explore: comms_events_public {
  label: "Comms Events (Public)"
  description: "Aggregated comms latency metrics (no emails)."
}

explore: os_expectations {
  label: "OS Expectations"
  description: "Targets/expectations per week/pod used to compare against time tracking."
}

# ------------------------------
# Cross-source KPI helpers (PUBLIC-safe)
# ------------------------------
explore: release_quality {
  label: "Release Quality Gate"
  description: "Pre-aggregated per-release health metrics (coverage, backlog, prod errors, gate pass/fail)."
}

explore: kpi_defects_per_100_tests {
  label: "KPI - Defects per 100 Tests"
}

explore: kpi_escape_rate_and_dde {
  label: "KPI - Escape Rate & DDE"
}
