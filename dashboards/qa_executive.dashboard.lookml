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

  - name: awaiting_regression_now
    title: Awaiting regression now
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status: "Ready for Regression,In Regression"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Bugs currently in agreed regression states (Ready for Regression, In Regression)."
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

  - name: entered_by_severity_30d
    title: Entered (last 30d) by Severity
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "30 days"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Bugs created in last 30 days grouped by Severity."
    row: 8
    col: 8
    width: 8
    height: 6

  - name: fixed_by_priority_7d
    title: Fixed (last 7d) by Priority
    type: looker_column
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.event_type, jira_bug_events_daily.event_date_date, jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    pivots: [jira_bug_events_daily.priority_label]
    filters:
      jira_bug_events_daily.event_type: "fixed"
      jira_bug_events_daily.event_date_date: "7 days"
    sorts: [jira_bug_events_daily.event_date_date]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "Jira (changelog) | Bugs fixed in last 7 days by priority."
    row: 14
    col: 0
    width: 8
    height: 6

  - name: fixed_by_priority_30d
    title: Fixed (last 30d) by Priority
    type: looker_column
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.event_type, jira_bug_events_daily.event_date_date, jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    pivots: [jira_bug_events_daily.priority_label]
    filters:
      jira_bug_events_daily.event_type: "fixed"
      jira_bug_events_daily.event_date_date: "30 days"
    sorts: [jira_bug_events_daily.event_date_date]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "Jira (changelog) | Bugs fixed in last 30 days by priority."
    row: 14
    col: 8
    width: 8
    height: 6

  - name: active_bugs_by_pod
    title: Active bugs by POD
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.team, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Current active bugs grouped by POD."
    row: 20
    col: 0
    width: 8
    height: 6

  - name: active_bugs_by_priority
    title: Active bugs by Priority
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.priority, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Current active bugs grouped by priority."
    row: 20
    col: 8
    width: 8
    height: 6

  - name: bugs_by_current_status
    title: Bugs by current status
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.status, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Current bugs grouped by Jira status."
    row: 26
    col: 0
    width: 8
    height: 6

  - name: active_bug_count_over_time
    title: Active bug count over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_active_bug_count_daily
    fields: [jira_active_bug_count_daily.metric_date_date, jira_active_bug_count_daily.active_bug_count]
    sorts: [jira_active_bug_count_daily.metric_date_date]
    listen:
      date_range: jira_active_bug_count_daily.metric_date_date
    note_text: "Jira snapshot | Daily active bug count trend."
    row: 26
    col: 8
    width: 8
    height: 6

  - name: reopened_over_time
    title: Reopened over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.event_date_date, jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "reopened"
    sorts: [jira_bug_events_daily.event_date_date]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "Jira (changelog) | Bugs reopened over time."
    row: 32
    col: 0
    width: 8
    height: 6

  - name: fix_version_proxy_milestone
    title: Fix Version (proxy milestone)
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.fix_versions, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "Jira | Active bugs grouped by Fix Version as milestone proxy."
    row: 32
    col: 8
    width: 8
    height: 6

  - name: header_bugsnag
    type: text
    title_text: "BugSnag"
    body_text: "Production stability overview."
    row: 38
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
    row: 40
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
    row: 40
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
    row: 40
    col: 10
    width: 6
    height: 6

  - name: header_gamebench
    type: text
    title_text: "GameBench"
    body_text: "Performance & stability (Android vs iOS)."
    row: 46
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
    row: 48
    col: 0
    width: 16
    height: 6

  - name: header_ops
    type: text
    title_text: "Operational QA metrics"
    body_text: "Fix fail, MTTR, build size and TestRail execution/BVT health."
    row: 54
    col: 0
    width: 16
    height: 2

  - name: jira_fix_fail_rate_trend
    title: Fix fail rate over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_fix_fail_rate_daily
    fields: [jira_fix_fail_rate_daily.event_date_date, jira_fix_fail_rate_daily.fix_fail_rate]
    sorts: [jira_fix_fail_rate_daily.event_date_date]
    listen:
      date_range: jira_fix_fail_rate_daily.event_date_date
    note_text: "Jira | Reopened / Fixed ratio by day."
    row: 56
    col: 0
    width: 8
    height: 6

  - name: jira_mttr_hours_trend
    title: MTTR (hours) over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_mttr_fixed_daily
    fields: [jira_mttr_fixed_daily.event_date_date, jira_mttr_fixed_daily.avg_mttr_hours]
    sorts: [jira_mttr_fixed_daily.event_date_date]
    listen:
      date_range: jira_mttr_fixed_daily.event_date_date
    note_text: "Jira | Average hours from created to fixed for bugs fixed each day."
    row: 56
    col: 8
    width: 8
    height: 6

  - name: build_size_mb_trend
    title: Build size (MB) over time
    type: looker_line
    model: panda_qa_metrics
    explore: build_size_manual
    fields: [build_size_manual.metric_date_date, build_size_manual.build_size_mb, build_size_manual.platform]
    pivots: [build_size_manual.platform]
    sorts: [build_size_manual.metric_date_date]
    listen:
      date_range: build_size_manual.metric_date_date
    note_text: "Manual build metrics | Daily build size trend by platform."
    row: 62
    col: 0
    width: 8
    height: 6

  - name: testrail_test_execution_trend
    title: Test execution (cases) over time
    type: looker_line
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.executed_cases]
    filters:
      testrail_runs_latest.is_completed: "yes"
    sorts: [testrail_runs_latest.completed_on_date]
    listen:
      date_range: testrail_runs_latest.completed_on_date
    note_text: "TestRail | Executed test cases per completed run date."
    row: 62
    col: 8
    width: 4
    height: 6

  - name: testrail_bvt_pass_rate_trend
    title: BVT pass rate over time
    type: looker_line
    model: panda_qa_metrics
    explore: testrail_bvt_latest
    fields: [testrail_bvt_latest.completed_on_date, testrail_bvt_latest.pass_rate]
    sorts: [testrail_bvt_latest.completed_on_date]
    listen:
      date_range: testrail_bvt_latest.completed_on_date
    note_text: "TestRail BVT | Daily pass rate trend for latest BVT runs."
    row: 62
    col: 12
    width: 4
    height: 6
