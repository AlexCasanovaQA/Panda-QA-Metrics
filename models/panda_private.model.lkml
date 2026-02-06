# Panda Private model
# Generated: 2026-01-08T12:27:33.921732Z

connection: "REPLACE_WITH_YOUR_BIGQUERY_CONNECTION"

include: "/views/*.view.lkml"

datagroup: panda_ingestion_dg {
  sql_trigger: SELECT MAX(updated_at) FROM `qa-panda-metrics.qa_metrics.ingestion_state` ;;
  max_cache_age: "15 minutes"
}

# Private explores (people-level joins enabled)
explore: jira_issues {
  label: "Jira — Issues (Private)"
  description: "Latest Jira issues snapshot (deduped)."
  join: dim_people {
    type: left_outer
    sql_on: ${jira_issues.assignee_account_id} = ${dim_people.jira_account_id} ;;
    relationship: many_to_one
  }
}

explore: jira_issue_events {
  label: "Jira — Issue Events (Private)"
  description: "Changelog items (status/severity/priority etc.)."
  join: dim_people {
    type: left_outer
    sql_on: ${jira_issue_events.author_account_id} = ${dim_people.jira_account_id} ;;
    relationship: many_to_one
  }
}

explore: jira_issue_status_times {
  label: "Jira — Cycle Times (Private)"
  description: "Per-issue timestamps for key status milestones (triage, ready for QA, resolved) + cycle times."
  join: jira_issues {
    type: left_outer
    sql_on: ${jira_issue_status_times.issue_id} = ${jira_issues.issue_id} ;;
    relationship: one_to_one
  }
  join: dim_people {
    type: left_outer
    sql_on: ${jira_issue_status_times.assignee_account_id} = ${dim_people.jira_account_id} ;;
    relationship: many_to_one
  }
}

explore: testrail_results {
  label: "TestRail — Results (Private)"
  description: "TestRail test results (supports per-QA metrics via created_by)."
  join: testrail_runs {
    type: left_outer
    sql_on: ${testrail_results.run_id} = ${testrail_runs.run_id} ;;
    relationship: many_to_one
  }
  join: dim_people {
    type: left_outer
    sql_on: ${testrail_results.created_by_id} = ${dim_people.testrail_user_id} ;;
    relationship: many_to_one
  }
}

explore: testrail_test_result_history {
  label: "TestRail — Result History (Private)"
  description: "Per-test first/last status + 'changed result' flag."
  join: dim_people {
    type: left_outer
    sql_on: ${testrail_test_result_history.last_created_by_id} = ${dim_people.testrail_user_id} ;;
    relationship: many_to_one
  }
}

explore: bugsnag_errors {
  label: "Bugsnag — Errors (Private)"
  description: "Latest Bugsnag errors snapshot (deduped)."
}

explore: qa_time_entries {
  label: "Manual — Time Entries (Private)"
  description: "Time tracking with people-level data."
  join: dim_people {
    type: left_outer
    sql_on: ${qa_time_entries.person_key} = ${dim_people.person_key} ;;
    relationship: many_to_one
  }
}

explore: dim_release {
  label: "Manual — Releases"
  description: "Release windows to map issues/errors/results to a release."
}


# ------------------------------
# Manual / ops tables (PRIVATE)
# ------------------------------

explore: exploratory_sessions {
  label: "Manual — Exploratory Sessions (Private)"
  description: "Exploratory session logs (people-level)."
  join: dim_people {
    type: left_outer
    sql_on: ${exploratory_sessions.person_key} = ${dim_people.person_key} ;;
    relationship: many_to_one
  }
}

explore: comms_events {
  label: "Manual — Comms Events (Private)"
  description: "Flags/responses logs (people-level)."
  join: requester {
    from: dim_people
    type: left_outer
    sql_on: ${comms_events.requester_email} = ${requester.email} ;;
    relationship: many_to_one
    view_label: "Requester"
  }
  join: responder {
    from: dim_people
    type: left_outer
    sql_on: ${comms_events.responder_email} = ${responder.email} ;;
    relationship: many_to_one
    view_label: "Responder"
  }
}

explore: os_expectations {
  label: "Manual — OS Expectations"
  description: "Weekly OS expectations (per pod)."
}

# ------------------------------
# Cross-source KPI helper views
# ------------------------------

explore: release_quality {
  label: "KPIs — Release Quality"
  join: dim_release {
    type: left_outer
    sql_on: ${release_quality.release_key} = ${dim_release.release_key} ;;
    relationship: many_to_one
  }
}

explore: kpi_defects_per_100_tests {
  label: "KPIs — Defects per 100 Tests"
  join: dim_release {
    type: left_outer
    sql_on: ${kpi_defects_per_100_tests.release_key} = ${dim_release.release_key} ;;
    relationship: many_to_one
  }
}

explore: kpi_escape_rate_and_dde {
  label: "KPIs — Escape Rate & DDE"
  join: dim_release {
    type: left_outer
    sql_on: ${kpi_escape_rate_and_dde.release_key} = ${dim_release.release_key} ;;
    relationship: many_to_one
  }
}
