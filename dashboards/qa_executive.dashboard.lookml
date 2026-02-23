- dashboard: qa_executive
  title: QA Executive
  layout: newspaper
  preferred_viewer: dashboards-next
  description: "Executive scoreboard for QA quality & stability (Jira + TestRail + BugSnag + GameBench). Default date range: last 7 days."
  refresh: 15 minutes

  filters:
  - name: date_range
    title: Date Range
    type: date_filter
    default_value: 7 days

  - name: pod
    title: POD
    type: field_filter
    model: panda_qa_metrics
    explore: jira_issues_latest
    field: jira_issues_latest.team

  - name: priority
    title: Priority
    type: field_filter
    model: panda_qa_metrics
    explore: jira_issues_latest
    field: jira_issues_latest.priority

  - name: severity
    title: Severity
    type: field_filter
    model: panda_qa_metrics
    explore: jira_issues_latest
    field: jira_issues_latest.severity

  - name: env
    title: GameBench Environment
    type: field_filter
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    field: gamebench_daily_metrics.environment

  - name: platform
    title: GameBench Platform
    type: field_filter
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    field: gamebench_daily_metrics.platform

  elements:
  - name: header_scoreboard
    type: text
    title_text: "Scoreboard"
    body_text: "Quick health view (today + active)."

  - name: bugs_entered_today
    title: Bugs entered today
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "today"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Count of bugs created today."
    row: 3
    col: 0
    width: 4
    height: 3

  - name: fixes_today
    title: Fixes today (Fixed)
    type: single_value
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "fixed"
      jira_bug_events_daily.event_date_date: "today"
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "Jira (changelog) | Bugs transitioned to Fixed today."
    row: 3
    col: 4
    width: 4
    height: 3

  - name: active_bugs_now
    title: Active bugs now
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Current bugs where statusCategory != Done."
    row: 3
    col: 8
    width: 4
    height: 3

  - name: awaiting_qa_verification
    title: Awaiting QA verification (Resolved)
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status: "Resolved"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Bugs currently in Resolved (Ready for QA)."
    row: 3
    col: 12
    width: 4
    height: 3

  - name: header_incoming
    type: text
    title_text: "Incoming defects"
    body_text: "Distribution + trend for bugs entered."
    row: 6
    col: 0
    width: 16
    height: 2

  - name: entered_by_severity_7d
    title: Entered (last 7d) by Severity
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "7 days"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Bugs created in last 7 days grouped by Severity."
    row: 8
    col: 0
    width: 8
    height: 6

  - name: entered_by_priority_trend_7d
    title: Bugs entered by day (last 7d) — Priority
    type: looker_line
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.created_date, jira_issues_latest.issues, jira_issues_latest.priority]
    pivots: [jira_issues_latest.priority]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "7 days"
    sorts: [jira_issues_latest.created_date]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Daily bug creation counts in last 7 days, pivoted by Priority."
    row: 8
    col: 8
    width: 8
    height: 6

  - name: header_bugsnag
    type: text
    title_text: "BugSnag"
    body_text: "Production stability overview."
    row: 14
    col: 0
    width: 16
    height: 2

  - name: bugsnag_active_errors
    title: Active production errors
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.active_errors]
    note_text: "BugSnag | Errors where status != resolved/closed."
    row: 16
    col: 0
    width: 5
    height: 3

  - name: bugsnag_high_critical_active
    title: High/Critical active errors
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.high_critical_active_errors]
    note_text: "BugSnag | Active errors with severity in (critical, error)."
    row: 16
    col: 5
    width: 5
    height: 3

  - name: bugsnag_active_by_severity
    title: Active errors by severity
    type: looker_pie
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.severity, bugsnag_errors_latest.active_errors]
    note_text: "BugSnag | Active errors grouped by severity."
    row: 16
    col: 10
    width: 6
    height: 6

  - name: header_gamebench
    type: text
    title_text: "GameBench"
    body_text: "Performance & stability (Android vs iOS)."
    row: 22
    col: 0
    width: 16
    height: 2

  - name: gb_median_fps_7d
    title: Median FPS (last 7d)
    type: looker_line
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.median_fps, gamebench_daily_metrics.platform]
    pivots: [gamebench_daily_metrics.platform]
    filters:
      gamebench_daily_metrics.metric_date_date: "7 days"
    sorts: [gamebench_daily_metrics.metric_date_date]
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_text: "GameBench | Daily median FPS (median across sessions), pivoted by platform."
    row: 24
    col: 0
    width: 16
    height: 6
