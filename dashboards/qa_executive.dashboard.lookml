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
    body_text: "Current snapshots + 7d trends (Android vs iOS)."
    row: 46
    col: 0
    width: 16
    height: 2

  - name: current_fps_by_platform
    title: Current snapshot | FPS by platform (latest day)
    type: looker_grid
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.platform, gamebench_daily_metrics.median_fps]
    filters:
      gamebench_daily_metrics.metric_date_date: "1 days"
    sorts: [gamebench_daily_metrics.metric_date_date desc, gamebench_daily_metrics.platform]
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_text: "GameBench | Current snapshot table using latest available day in the last day, grouped by platform."
    row: 48
    col: 0
    width: 8
    height: 4

  - name: current_session_stability
    title: Current KPI | Session stability (proxy)
    type: single_value
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.fps_stability_pct]
    filters:
      gamebench_daily_metrics.metric_date_date: "1 days"
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_text: "GameBench proxy | Uses fps_stability_pct as current session stability proxy (no crash-free session metric available in gamebench_daily_metrics)."
    row: 48
    col: 8
    width: 8
    height: 4

  - name: gb_median_fps_7d
    title: Trend (7d) | Median FPS by platform
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
    row: 52
    col: 0
    width: 16
    height: 6

  - name: header_ops
    type: text
    title_text: "Operational QA metrics"
    body_text: "Current snapshots + trends for fix fail, MTTR, build size and TestRail execution/BVT health."
    row: 58
    col: 0
    width: 16
    height: 2

  - name: jira_fix_fail_rate_trend
    title: Trend | Fix fail rate over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_fix_fail_rate_daily
    fields: [jira_fix_fail_rate_daily.event_date_date, jira_fix_fail_rate_daily.fix_fail_rate]
    sorts: [jira_fix_fail_rate_daily.event_date_date]
    listen:
      date_range: jira_fix_fail_rate_daily.event_date_date
    note_text: "Jira | Reopened / Fixed ratio by day."
    row: 60
    col: 0
    width: 8
    height: 6

  - name: jira_mttr_hours_trend
    title: Trend | MTTR (hours) over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_mttr_fixed_daily
    fields: [jira_mttr_fixed_daily.event_date_date, jira_mttr_fixed_daily.avg_mttr_hours]
    sorts: [jira_mttr_fixed_daily.event_date_date]
    listen:
      date_range: jira_mttr_fixed_daily.event_date_date
    note_text: "Jira | Average hours from created to fixed for bugs fixed each day."
    row: 60
    col: 8
    width: 8
    height: 6

  - name: current_build_size_by_platform
    title: Current snapshot | Build size by platform
    type: looker_grid
    model: panda_qa_metrics
    explore: build_size_manual
    fields: [build_size_manual.metric_date_date, build_size_manual.platform, build_size_manual.environment, build_size_manual.build_version, build_size_manual.build_size_mb]
    filters:
      build_size_manual.metric_date_date: "7 days"
    sorts: [build_size_manual.metric_date_date desc, build_size_manual.platform]
    note_text: "Manual build metrics | Current snapshot per platform from latest available builds."
    row: 66
    col: 0
    width: 8
    height: 4

  - name: build_size_mb_trend
    title: Trend | Build size (MB) over time
    type: looker_line
    model: panda_qa_metrics
    explore: build_size_manual
    fields: [build_size_manual.metric_date_date, build_size_manual.build_size_mb, build_size_manual.platform]
    pivots: [build_size_manual.platform]
    sorts: [build_size_manual.metric_date_date]
    listen:
      date_range: build_size_manual.metric_date_date
    note_text: "Manual build metrics | Daily build size trend by platform."
    row: 70
    col: 0
    width: 8
    height: 6

  - name: header_testrail
    type: text
    title_text: "TestRail"
    body_text: "Execution throughput and latest quality signal."
    row: 66
    col: 8
    width: 8
    height: 2

  - name: testcases_completed_by_day_7d
    title: Trend (7d) | Test cases completed by day
    type: looker_line
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.executed_cases]
    filters:
      testrail_runs_latest.is_completed: "yes"
      testrail_runs_latest.completed_on_date: "7 days"
    sorts: [testrail_runs_latest.completed_on_date]
    listen:
      date_range: testrail_runs_latest.completed_on_date
    note_text: "TestRail | Ejecutado = passed + failed + blocked + retest (excluye untested) por día de completed_on."
    row: 68
    col: 8
    width: 8
    height: 4

  - name: current_pass_rate
    title: Current KPI | Pass rate (latest run)
    type: single_value
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.pass_rate]
    filters:
      testrail_runs_latest.is_completed: "yes"
    sorts: [testrail_runs_latest.completed_on_date desc, testrail_runs_latest.run_id desc]
    limit: 1
    listen:
      date_range: testrail_runs_latest.completed_on_date
    note_text: "TestRail | Pass rate = SUM(passed) / SUM(passed + failed + blocked + retest) del último run completado disponible."
    row: 72
    col: 8
    width: 4
    height: 3

  - name: bvt_pass_rate_latest_build
    title: Current KPI | BVT pass rate (latest build)
    type: single_value
    model: panda_qa_metrics
    explore: testrail_bvt_latest
    fields: [testrail_bvt_latest.completed_on_date, testrail_bvt_latest.pass_rate]
    sorts: [testrail_bvt_latest.completed_on_date desc, testrail_bvt_latest.run_id desc]
    limit: 1
    listen:
      date_range: testrail_bvt_latest.completed_on_date
    note_text: "TestRail BVT | Pass rate del último build/run BVT disponible (según pass_rate_calc en testrail_bvt_latest)."
    row: 72
    col: 12
    width: 4
    height: 3
