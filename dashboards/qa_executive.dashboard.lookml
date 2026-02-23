dashboard: qa_executive {
  title: "QA Executive"
  description: "Executive scoreboard for QA quality & stability (Jira + TestRail + BugSnag + GameBench). Default date range: last 7 days."
  preferred_viewer: dashboards-next

  filter: date_range {
    type: date_filter
    default_value: "7 days"
  }

  filter: pod {
    type: field_filter
    field: jira_issues_latest.team
    default_value: ""
  }

  filter: priority {
    type: field_filter
    field: jira_issues_latest.priority
    default_value: ""
  }

  filter: severity {
    type: field_filter
    field: jira_issues_latest.severity
    default_value: ""
  }

  filter: env {
    type: field_filter
    field: gamebench_daily_metrics.environment
    default_value: ""
  }

  filter: platform {
    type: field_filter
    field: gamebench_daily_metrics.platform
    default_value: ""
  }

  # ---------------------------
  # Scoreboard
  # ---------------------------
  element: bugs_entered_today {
    title: "Bugs entered today"
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.created_date: "today"]
    note_text: "Jira | Count of bugs created today."
    listen: {
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    }
  }

  element: fixes_today {
    title: "Fixes today (Fixed)"
    type: single_value
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.bugs]
    filters: [jira_bug_events_daily.event_type: "fixed", jira_bug_events_daily.event_date_date: "today"]
    note_text: "Jira (changelog) | Count of bugs transitioned to Fixed today."
    listen: {
      date_range: jira_bug_events_daily.event_date_date
    }
  }

  element: active_bugs_now {
    title: "Active bugs now"
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.status_category: "-Done"]
    note_text: "Jira | Current bugs where statusCategory != Done."
    listen: {
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    }
  }

  element: awaiting_qa_verification {
    title: "Awaiting QA verification (Resolved)"
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.status: "Resolved"]
    note_text: "Jira | Bugs currently in Resolved (Ready for QA)."
    listen: {
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    }
  }

  # ---------------------------
  # Incoming defects
  # ---------------------------
  element: entered_by_severity_7d {
    title: "Entered (last 7d) by Severity"
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity, jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.created_date: "7 days"]
    note_text: "Jira | Bugs created in last 7 days grouped by Severity."
    listen: { pod: jira_issues_latest.team }
  }

  element: entered_by_severity_30d {
    title: "Entered (last 30d) by Severity"
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity, jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.created_date: "30 days"]
    note_text: "Jira | Bugs created in last 30 days grouped by Severity."
    listen: { pod: jira_issues_latest.team }
  }

  element: entered_by_priority_trend_7d {
    title: "Bugs entered by day (last 7d) — Priority"
    type: looker_line
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.created_date, jira_issues_latest.issues, jira_issues_latest.priority]
    pivots: [jira_issues_latest.priority]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.created_date: "7 days"]
    sorts: [jira_issues_latest.created_date]
    note_text: "Jira | Daily bug creation counts in last 7 days, pivoted by Priority."
    listen: { pod: jira_issues_latest.team }
  }

  # ---------------------------
  # Fixes & quality
  # ---------------------------
  element: fixed_by_priority_7d {
    title: "Fixed (last 7d) by Priority"
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    filters: [jira_bug_events_daily.event_type: "fixed", jira_bug_events_daily.event_date_date: "7 days"]
    note_text: "Jira (changelog) | Bugs transitioned to Fixed in last 7 days grouped by Priority."
    listen: { date_range: jira_bug_events_daily.event_date_date }
  }

  element: reopened_trend_30d {
    title: "Reopened over time (last 30d)"
    type: looker_line
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.event_date_date, jira_bug_events_daily.bugs]
    filters: [jira_bug_events_daily.event_type: "reopened", jira_bug_events_daily.event_date_date: "30 days"]
    sorts: [jira_bug_events_daily.event_date_date]
    note_text: "Jira (changelog) | Count of bugs that transitioned to Reopened per day (last 30 days)."
  }

  element: fix_fail_rate_30d {
    title: "Fix fail rate over time (last 30d)"
    type: looker_line
    model: panda_qa_metrics
    explore: jira_fix_fail_rate_daily
    fields: [jira_fix_fail_rate_daily.event_date_date, jira_fix_fail_rate_daily.fix_fail_rate]
    filters: [jira_fix_fail_rate_daily.event_date_date: "30 days"]
    sorts: [jira_fix_fail_rate_daily.event_date_date]
    note_text: "Jira (changelog) | Fix fail rate = reopened / fixed per day (last 30 days)."
  }

  element: mttr_to_fixed_7d {
    title: "MTTR (created → Fixed) for fixes in range"
    type: single_value
    model: panda_qa_metrics
    explore: jira_mttr_fixed_daily
    fields: [jira_mttr_fixed_daily.avg_mttr_hours]
    filters: [jira_mttr_fixed_daily.event_date_date: "7 days"]
    note_text: "Jira (changelog) | Average time (hours) from Created to first transition into Fixed for issues fixed in the selected range."
    listen: { date_range: jira_mttr_fixed_daily.event_date_date }
  }

  # ---------------------------
  # Active backlog composition
  # ---------------------------
  element: active_by_pod {
    title: "Active bugs by POD (statusCategory != Done)"
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.team, jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.status_category: "-Done"]
    note_text: "Jira | Current active bugs grouped by POD."
  }

  element: active_by_status {
    title: "Active bugs by status"
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.status, jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.status_category: "-Done"]
    note_text: "Jira | Current active bugs grouped by current status."
  }

  element: active_over_time_180d {
    title: "Active bug count over time (180d)"
    type: looker_line
    model: panda_qa_metrics
    explore: jira_active_bug_count_daily
    fields: [jira_active_bug_count_daily.metric_date_date, jira_active_bug_count_daily.active_bug_count]
    filters: [jira_active_bug_count_daily.metric_date_date: "180 days"]
    sorts: [jira_active_bug_count_daily.metric_date_date]
    note_text: "Jira (changelog-derived) | Daily active bug count over last 180 days."
  }

  element: active_by_milestone {
    title: "Active bugs by milestone (fixVersion)"
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.fix_versions, jira_issues_latest.issues]
    filters: [jira_issues_latest.issue_type: "Bug,Defect", jira_issues_latest.status_category: "-Done"]
    note_text: "Jira | Active bugs grouped by fixVersion. May be incomplete—use to drive better hygiene."
  }

  # ---------------------------
  # TestRail
  # ---------------------------
  element: testrail_cases_executed_7d {
    title: "Test cases executed by day (last 7d)"
    type: looker_line
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.executed_cases]
    filters: [testrail_runs_latest.is_completed: "yes", testrail_runs_latest.completed_on_date: "7 days"]
    sorts: [testrail_runs_latest.completed_on_date]
    note_text: "TestRail | Sum of passed+failed+blocked+retest per day for completed runs."
  }

  element: testrail_pass_rate_7d {
    title: "Pass rate (last 7d)"
    type: single_value
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.pass_rate]
    filters: [testrail_runs_latest.is_completed: "yes", testrail_runs_latest.completed_on_date: "7 days"]
    note_text: "TestRail | Pass rate across executed results in last 7 days."
  }

  element: testrail_bvt_latest {
    title: "BVT pass rate (latest Basic BVT run)"
    type: single_value
    model: panda_qa_metrics
    explore: testrail_bvt_latest
    fields: [testrail_bvt_latest.pass_rate]
    note_text: "TestRail | Latest run whose name matches 'Basic BVT' (or contains 'BVT')."
  }

  # ---------------------------
  # BugSnag
  # ---------------------------
  element: bugsnag_active_errors {
    title: "Active production errors"
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.active_errors]
    note_text: "BugSnag | Errors where status != resolved/closed."
  }

  element: bugsnag_high_critical_active {
    title: "High/Critical active errors"
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.high_critical_active_errors]
    note_text: "BugSnag | Active errors with severity in (critical, error)."
  }

  element: bugsnag_active_by_severity {
    title: "Active errors by severity"
    type: looker_pie
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.severity, bugsnag_errors_latest.active_errors]
    note_text: "BugSnag | Active errors grouped by severity."
  }

  element: bugsnag_new_errors_7d {
    title: "New errors (last 7d)"
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.errors]
    filters: [bugsnag_errors_latest.first_seen_date: "7 days"]
    note_text: "BugSnag | Count of unique errors first seen in last 7 days."
  }

  # ---------------------------
  # GameBench
  # ---------------------------
  element: gb_median_fps_7d {
    title: "Median FPS (last 7d)"
    type: looker_line
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.median_fps, gamebench_daily_metrics.platform]
    pivots: [gamebench_daily_metrics.platform]
    filters: [gamebench_daily_metrics.metric_date_date: "7 days"]
    sorts: [gamebench_daily_metrics.metric_date_date]
    note_text: "GameBench | Daily median FPS (median across sessions), pivoted by platform."
    listen: { env: gamebench_daily_metrics.environment }
  }

  element: gb_stability_7d {
    title: "FPS stability % (last 7d)"
    type: looker_line
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.fps_stability_pct, gamebench_daily_metrics.platform]
    pivots: [gamebench_daily_metrics.platform]
    filters: [gamebench_daily_metrics.metric_date_date: "7 days"]
    sorts: [gamebench_daily_metrics.metric_date_date]
    note_text: "GameBench | Daily FPS stability percentage, pivoted by platform."
    listen: { env: gamebench_daily_metrics.environment }
  }

  element: build_size_latest {
    title: "Current build size (manual)"
    type: single_value
    model: panda_qa_metrics
    explore: build_size_manual
    fields: [build_size_manual.build_size_mb]
    filters: [build_size_manual.metric_date_date: "7 days"]
    note_text: "Manual | Populate qa_metrics.build_size_manual with latest build sizes (MB) by platform."
  }
}
