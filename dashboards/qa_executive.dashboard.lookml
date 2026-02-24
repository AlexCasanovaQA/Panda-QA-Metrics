- dashboard: qa_executive
  title: QA Executive
  layout: newspaper
  preferred_viewer: dashboards-next
  description: "Executive QA dashboard with curated KPI definitions, clearer visual hierarchy, and consistent chart sizing/colors (Jira + TestRail + BugSnag + GameBench)."
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
    field: jira_issues_latest.severity_normalized

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
    title_text: "QA Executive Scoreboard"
    body_text: "Top KPIs (current state): incident inflow, throughput, and live backlog. Each tile includes an info icon (i) with the KPI definition and calculation."
    row: 0
    col: 0
    width: 24
    height: 2

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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Number of bugs/defects created today in Jira. Calculation: COUNT(issue_key) filtered by issue_type in (Bug, Defect) and created_date=today. Use: Detect daily intake spikes and compare against triage/fix capacity."
    row: 3
    col: 0
    width: 6
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
    note_display: hover
    note_text: "Definition: Bugs that moved to Fixed status today. Calculation: COUNT of changelog events with event_type=fixed and event_date=today. Note: This tile keeps a fixed daily window and does not depend on the global date_range filter."
    row: 3
    col: 6
    width: 6
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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Current active bug backlog. Calculation: COUNT of issues where statusCategory != Done. Use: Measure current operational pressure and pending closure volume."
    row: 6
    col: 0
    width: 24
    height: 3

  - name: qa_verification_queue_now
    title: QA verification queue now
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.qa_verification_state: "QA Verification"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Current QA verification queue. Calculation: COUNT of bugs with qa_verification_state='QA Verification' (normalizes states such as Ready for QA, In QA, Awaiting QA Verification)."
    row: 3
    col: 12
    width: 6
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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Bugs waiting for or currently in regression. Calculation: COUNT with status in (Ready for Regression, In Regression). Use: Evaluate ongoing regression testing load."
    row: 3
    col: 18
    width: 6
    height: 3

  - name: header_incoming
    type: text
    title_text: "Incoming defects"
    body_text: "Bug intake analysis by severity and priority, with proportional distribution and daily trend."
    row: 9
    col: 0
    width: 24
    height: 2

  - name: entered_by_severity
    title: Bugs entered by Severity
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity_normalized, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
    listen:
      date_range: jira_issues_latest.created_date
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Percentage distribution of bugs created by severity for the selected Date Range. Calculation: COUNT of bugs grouped by severity where created_date is controlled by the dashboard Date Range filter."
    show_value_labels: true
    label_type: labPer
    series_colors: {"(S0) Blocker": "#D64550", "(S1) Critical": "#F28B30", "(S2) Major": "#F2C94C", "(S3) Minor": "#2D9CDB", "(S4) Trivial": "#6FCF97", "(unknown)": "#BDBDBD"}
    row: 11
    col: 0
    width: 12
    height: 6

  - name: entered_by_priority
    title: Bugs entered by Priority
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.priority, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
    listen:
      date_range: jira_issues_latest.created_date
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Entered = created_date in Date Range. Shows the percentage distribution of bugs created by priority for the selected Date Range."
    show_value_labels: true
    label_type: labPer
    row: 11
    col: 12
    width: 12
    height: 6


  - name: incoming_bugs_created_daily_by_priority
    title: Incoming bugs created daily (Date Range)
    type: looker_column
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.created_date, jira_issues_latest.priority, jira_issues_latest.issues]
    pivots: [jira_issues_latest.priority]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
    sorts: [jira_issues_latest.created_date]
    listen:
      date_range: jira_issues_latest.created_date
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Daily trend of incoming bugs by priority for the selected Date Range. Calculation: COUNT of bugs by created_date and priority. Use: Detect whether critical intake grows faster than resolution capacity."
    series_colors: {Highest: "#D64550", High: "#F28B30", Medium: "#F2C94C", Low: "#2D9CDB", Lowest: "#6FCF97"}
    row: 17
    col: 0
    width: 24
    height: 6

  - name: fixed_by_priority
    title: Bugs fixed by Priority
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "fixed"
    sorts: [jira_bug_events_daily.bugs desc]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_display: hover
    note_text: "Definition: Distribution of bugs fixed by priority for the selected Date Range. Calculation: COUNT of fixed events grouped by priority_label where event_date is controlled by the dashboard Date Range filter."
    row: 23
    col: 0
    width: 12
    height: 6

  - name: fixed_daily_by_priority
    title: Bugs fixed daily by Priority
    type: looker_column
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.event_date_date, jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    pivots: [jira_bug_events_daily.priority_label]
    filters:
      jira_bug_events_daily.event_type: "fixed"
    sorts: [jira_bug_events_daily.event_date_date]
    listen:
      date_range: jira_bug_events_daily.event_date_date
      pod: jira_bug_events_daily.pod
      priority: jira_bug_events_daily.priority_label
      severity: jira_bug_events_daily.severity_label
    note_display: hover
    note_text: "Definition: Daily trend of fixed bugs by priority for the selected Date Range. Calculation: COUNT of event_type=fixed by event_date and priority_label. Use: Compare fix throughput by priority over time."
    stacking: normal
    row: 23
    col: 12
    width: 12
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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Active backlog split by POD/team. Calculation: COUNT of active bugs (statusCategory != Done) grouped by team. Use: Balance workload across pods."
    row: 29
    col: 0
    width: 12
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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Active backlog by current priority. Calculation: COUNT of active bugs grouped by priority. Use: Validate the mix of pending criticality."
    row: 29
    col: 12
    width: 12
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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Distribution of bugs by current Jira status. Calculation: COUNT of bugs grouped by status. Use: Identify bottlenecks in QA/dev workflow."
    row: 35
    col: 0
    width: 12
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
    note_display: hover
    note_text: "Definition: Daily evolution of active bug inventory. Calculation: Daily active_bug_count snapshot by date. Use: See whether backlog is converging or diverging."
    series_colors: {jira_active_bug_count_daily.active_bug_count: "#2F80ED"}
    row: 35
    col: 12
    width: 12
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
    note_display: hover
    note_text: "Definition: Reopened bugs per day. Calculation: COUNT of changelog events with event_type=reopened by date. Use: Proxy for fix quality and functional escapes."
    series_colors: {jira_bug_events_daily.bugs: "#EB5757"}
    row: 41
    col: 0
    width: 12
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
      severity: jira_issues_latest.severity_normalized
    note_display: hover
    note_text: "Definition: Active bugs by fixVersion (milestone proxy). Calculation: COUNT of active bugs grouped by fix_versions. Use: Prioritize by release/milestone."
    row: 41
    col: 12
    width: 12
    height: 6

  - name: header_bugsnag
    type: text
    title_text: "BugSnag"
    body_text: "Production stability: active error volume and BugSnag severity mix."
    row: 47
    col: 0
    width: 24
    height: 2

  - name: bugsnag_active_errors
    title: Active production errors
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.active_errors]
    note_display: hover
    note_text: "Definition: Active production errors not yet closed. Calculation: COUNT of errors where status is not in resolved/closed."
    row: 49
    col: 0
    width: 6
    height: 3

  - name: bugsnag_high_critical_active
    title: High/Critical active errors
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.high_critical_active_errors]
    note_display: hover
    note_text: "Definition: Highest-impact subset of active errors. Calculation: COUNT of active errors with severity in (critical, error)."
    row: 49
    col: 6
    width: 6
    height: 3

  - name: bugsnag_active_by_severity
    title: Active errors by severity
    type: looker_pie
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.severity, bugsnag_errors_latest.active_errors]
    note_display: hover
    note_text: "Definition: Composition of active errors by severity. Calculation: COUNT of active_errors grouped by severity. Use: Understand the current risk profile."
    series_colors: {critical: "#D64550", error: "#F28B30", warning: "#F2C94C", info: "#56CCF2"}
    row: 49
    col: 12
    width: 12
    height: 6

  - name: header_gamebench
    type: text
    title_text: "GameBench"
    body_text: "Gameplay performance: current snapshots and trends by platform/environment."
    row: 55
    col: 0
    width: 24
    height: 2

  - name: current_fps_by_platform
    title: Current snapshot | FPS by platform (latest day)
    type: looker_grid
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.platform, gamebench_daily_metrics.median_fps]
    filters:
      gamebench_daily_metrics.is_latest_metric_date: "yes"
    sorts: [gamebench_daily_metrics.metric_date_date desc, gamebench_daily_metrics.platform]
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_display: hover
    note_text: "Definition: Snapshot of median FPS by platform on the latest available day in GameBench daily metrics. Calculation: median_fps filtered to is_latest_metric_date = yes."
    row: 57
    col: 0
    width: 12
    height: 5

  - name: current_session_stability
    title: Current KPI | Session stability (proxy)
    type: single_value
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.fps_stability_pct]
    filters:
      gamebench_daily_metrics.is_latest_metric_date: "yes"
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_display: hover
    note_text: "Definition: Current session stability proxy from the latest available day in GameBench daily metrics. Calculation: fps_stability_pct filtered to is_latest_metric_date = yes. Note: Used as a proxy because crash-free sessions are not available in this explore."
    row: 57
    col: 12
    width: 12
    height: 5

  - name: gb_median_fps_7d
    title: Trend | Median FPS by platform
    type: looker_line
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.median_fps, gamebench_daily_metrics.platform]
    pivots: [gamebench_daily_metrics.platform]
    sorts: [gamebench_daily_metrics.metric_date_date]
    listen:
      date_range: gamebench_daily_metrics.metric_date_date
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_display: hover
    note_text: "Definition: Daily median FPS trend by platform. Calculation: median_fps by date pivoted by platform, governed by the global date_range."
    series_colors: {Android: "#27AE60", iOS: "#2D9CDB"}
    row: 62
    col: 0
    width: 24
    height: 6

  - name: header_ops
    type: text
    title_text: "Operational QA metrics"
    body_text: "Operational QA metrics: fix quality, resolution speed, build size, and test execution."
    row: 68
    col: 0
    width: 24
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
    note_display: hover
    note_text: "Definition: Daily fix fail rate. Calculation: reopened/fixed per day. Interpretation: Higher values mean more fixes return due to regressions or insufficient coverage."
    series_colors: {jira_fix_fail_rate_daily.fix_fail_rate: "#EB5757"}
    row: 70
    col: 0
    width: 12
    height: 6

  - name: jira_mttr_hours_trend
    title: Trend | MTTR (hours) over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_mttr_claimed_fixed_daily
    fields: [jira_mttr_claimed_fixed_daily.event_date_date, jira_mttr_claimed_fixed_daily.avg_mttr_hours]
    filters:
      jira_mttr_claimed_fixed_daily.event_date_date: "7 days"
    sorts: [jira_mttr_claimed_fixed_daily.event_date_date]
    listen:
      date_range: jira_mttr_claimed_fixed_daily.event_date_date
    note_display: hover
    note_text: "Definition: Daily operational MTTR in hours. Calculation: average(first transition to Resolved/Closed/Verified - created_at), aggregated by claimed fixed date."
    series_colors: {jira_mttr_claimed_fixed_daily.avg_mttr_hours: "#9B51E0"}
    row: 70
    col: 12
    width: 12
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
    note_display: hover
    note_text: "Definition: Most recent build size by platform/environment. Calculation: Snapshot from manual table within a 7-day window ordered by descending date."
    row: 76
    col: 0
    width: 12
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
    note_display: hover
    note_text: "Definition: Build size evolution in MB by platform. Calculation: build_size_mb by date pivoted by platform."
    series_colors: {Android: "#27AE60", iOS: "#2D9CDB"}
    row: 80
    col: 0
    width: 12
    height: 6

  - name: header_testrail
    type: text
    title_text: "TestRail"
    body_text: "TestRail execution health: daily throughput and quality signal from the latest run/build."
    row: 76
    col: 12
    width: 12
    height: 2

  - name: testcases_completed_by_day_7d
    title: Trend | Test cases completed by day
    type: looker_line
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.executed_cases]
    filters:
      testrail_runs_latest.is_completed: "yes"
    sorts: [testrail_runs_latest.completed_on_date]
    listen:
      date_range: testrail_runs_latest.completed_on_date
    note_display: hover
    note_text: "Definition: Executed test cases per day (excludes untested). Calculation: passed+failed+blocked+retest by completed_on, controlled by global date_range."
    series_colors: {testrail_runs_latest.executed_cases: "#2D9CDB"}
    row: 78
    col: 12
    width: 12
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
    note_display: hover
    note_text: "Definition: Pass rate of the latest completed run. Calculation: SUM(passed)/SUM(passed+failed+blocked+retest) using the most recent run by completed_on and run_id."
    row: 82
    col: 12
    width: 6
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
    note_display: hover
    note_text: "Definition: BVT pass rate for the latest available build/run. Calculation: pass_rate from testrail_bvt_latest for the most recent record."
    row: 82
    col: 18
    width: 6
    height: 3
