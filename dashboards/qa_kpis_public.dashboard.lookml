- dashboard: qa_kpis_public
  title: QA KPIs - Public (Leadership)
  layout: newspaper
  preferred_viewer: dashboards-next
  refresh: 1 hour
  filters:
  - name: date_range
    title: Date Range
    type: date_filter
    default_value: 90 days
  - name: pod
    title: POD
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.pod
  - name: priority
    title: Priority
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.priority_label
  - name: feature
    title: Feature
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.feature
  - name: release
    title: Release
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.release
  - name: sprint
    title: Sprint
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.sprint
  - name: severity
    title: Severity
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.severity
  elements:
  - name: intro_text
    type: text
    title_text: Executive QA health overview
    body_text: 'Focus: backlog, incident risk, execution signal, and SLA compliance. Hover ⓘ for definitions.'
    row: 0
    col: 0
    width: 24
    height: 3
    subtitle_text: Latest snapshot + key trends (use filters to slice)
  - name: section_at_a_glance
    type: text
    title_text: Executive snapshot
    subtitle_text: Latest week (or latest available period)
    body_text: ''
    row: 4
    col: 0
    width: 24
    height: 2
  - name: kpi_p5
    type: single_value
    title: P5 - Open Defect Backlog
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P5
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 6
    col: 0
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#d62728"
    note:
      text: "Total number of unresolved defects at the end of the period. Calc: COUNT of Bug issues where resolutiondate IS NULL or status not in Done/Resolved/Closed at snapshot. Window: Snapshot at end of week / sprint / release. Target: Backlog stable or trending down; critical backlog subject to strict limits."
      display: hover
  - name: kpi_p6
    type: single_value
    title: P6 - Open Critical & High Defects
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P6
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 6
    col: 6
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#d62728"
    note:
      text: "Number of unresolved Critical and High priority defects. Calc: COUNT of Bug issues where priority in ('Blocker','Critical','High') and resolutiondate IS NULL. Window: Snapshot at end of week / sprint / release. Target: Target 0 open Critical at release; High below agreed limit per feature."
      display: hover
  - name: kpi_p7
    type: single_value
    title: P7 - Average Age of Open Defects
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P7
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 6
    col: 12
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#d62728"
    note:
      text: "Average number of days that currently open bugs have been unresolved. Calc: Average DAYS between snapshot date and created for bugs where resolutiondate IS NULL. Window: Snapshot (trend weekly). Target: P0/P1 should have very low average age (for example <7 days)."
      display: hover
  - name: kpi_p11_snapshot
    type: single_value
    title: P11 - SLA Compliance (Critical/High)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P11
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 6
    col: 18
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#2ca02c"
    note:
      text: "Percentage of Critical/High defects resolved within the agreed resolution SLA. Calc: Resolved Critical/High bugs within SLA window / total Critical/High resolved in period. Window: Per sprint; rolling 4 weeks. Target: Target >=95% for Critical, >=90% for High."
      display: hover
  - name: kpi_p20
    type: single_value
    title: P20 - Active Production Errors
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P20
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 10
    col: 0
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#d62728"
    note:
      text: "Number of distinct Bugsnag errors that are still active (not fixed). Calc: COUNT DISTINCT error_id where status != 'fixed' and last_seen within monitoring window. Window: Daily snapshot; weekly trend. Target: Should trend down; specific thresholds per game."
      display: hover
  - name: kpi_p21
    type: single_value
    title: P21 - High/Critical Active Errors
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P21
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 10
    col: 6
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#d62728"
    note:
      text: "Number of active production errors with high severity. Calc: COUNT DISTINCT error_id where severity in ('error','critical') AND status != 'fixed'. Window: Daily snapshot; weekly trend. Target: Aim for zero open critical errors."
      display: hover
  - name: kpi_p14_snapshot
    type: single_value
    title: P14 - Pass Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P14
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 10
    col: 12
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#2ca02c"
    note:
      text: "Percentage of executed test cases that passed. Calc: SUM(passed_count) / SUM(passed_count + failed_count + blocked_count + retest_count). Window: Daily, per sprint, per release. Target: Target for release builds typically >=95% depending on risk."
      display: hover
  - name: kpi_p31_snapshot
    type: single_value
    title: P31 - Bug Escape Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P31
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week desc
    limit: 1
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 10
    col: 18
    width: 6
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#d62728"
    note:
      text: "Share of defects that escape to production, broken down by severity (Blocker/Critical/Major). Calc: (Defects found in production / (Pre-release defects + production defects)) by severity. Window: Per release and weekly. Target: High expectation: 0–2% Blocker/Critical; <4% Majors."
      display: hover
  - name: at_a_glance_note
    type: text
    title_text: Notes for leaders
    subtitle_text: ''
    body_text: 'Snapshot tiles show the latest week. Use trends to validate direction and stability; investigate spikes by filtering POD/Feature/Severity.'
    row: 140
    col: 0
    width: 24
    height: 3  - name: section_defects
    type: text
    title_text: Defects lifecycle
    subtitle_text: Creation → closure → reopen trends
    body_text: ''
    row: 14
    col: 0
    width: 24
    height: 2
  - name: kpi_p1
    type: looker_line
    title: P1 - Defects Created
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P1
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 16
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Number of new defect tickets created in the selected period. Calc: COUNT of issues where issue_type = 'Bug' and created date is in the period. Window: Weekly, per sprint, per release. Target: No fixed target; monitor trend and unexpected spikes per POD."
      display: hover
  - name: kpi_p2
    type: looker_line
    title: P2 - Defects Closed
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P2
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 16
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Number of defect tickets resolved or closed in the selected period. Calc: COUNT of Bug issues with resolutiondate in the period and status in Done/Resolved/Closed. Window: Weekly, per sprint, per release. Target: Over time, Closed >= Created to avoid backlog growth."
      display: hover
  - name: kpi_p3
    type: looker_line
    title: P3 - Defects Reopened
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P3
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 22
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Number of defect tickets that were reopened after being resolved. Calc: COUNT of Bug issues that transition from resolved/closed back to an open/reopened status during the period. Window: Weekly, per sprint. Target: As low as possible; aim for <3% of closed defects."
      display: hover
  - name: kpi_p4
    type: looker_line
    title: P4 - Defect Reopen Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P4
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 22
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of closed defects that were subsequently reopened. Calc: P3 (Defects Reopened) / P2 (Defects Closed) in the same period. Window: Weekly, per sprint, rolling 4 weeks. Target: Target <3–5%; stricter limit for Critical/High."
      display: hover
  - name: section_timeliness
    type: text
    title_text: Timeliness & SLA
    subtitle_text: How quickly issues move through triage and resolution
    body_text: ''
    row: 28
    col: 0
    width: 24
    height: 2
  - name: kpi_p9
    type: looker_line
    title: P9 - Time to Triage
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P9
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 30
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time from defect creation until it reaches the agreed triage state. Calc: Average HOURS between created and first timestamp where status is triage state. Window: Per sprint; rolling 4 weeks. Target: Target <24h for Critical/High defects."
      display: hover
  - name: kpi_p10
    type: looker_line
    title: P10 - Time to Resolution (MTTR)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P10
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 30
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time from defect creation until resolution. Calc: Average DAYS between created and resolutiondate for bugs resolved in period. Window: Per sprint; rolling 4 and 12 weeks. Target: Critical issues resolved within agreed SLA (for example <3 days)."
      display: hover
  - name: kpi_p11
    type: looker_line
    title: P11 - SLA Compliance for Critical/High Defects
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P11
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 36
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of Critical/High defects resolved within the agreed resolution SLA. Calc: Resolved Critical/High bugs within SLA window / total Critical/High resolved in period. Window: Per sprint; rolling 4 weeks. Target: Target >=95% for Critical, >=90% for High."
      display: hover
  - name: kpi_p8
    type: looker_line
    title: P8 - Defect Density (Bugs per 100 Story Points)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P8
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 36
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Defects created relative to the amount of delivered work. Calc: Bugs created in sprint / completed story points in same sprint * 100. Window: Per sprint / release. Target: Benchmark per POD; track trend, not absolute value."
      display: hover
  - name: section_test_execution
    type: text
    title_text: Test execution
    subtitle_text: Volume + outcomes + coverage
    body_text: ''
    row: 42
    col: 0
    width: 24
    height: 2
  - name: kpi_p12
    type: looker_line
    title: P12 - Test Runs Executed
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P12
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 44
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Number of TestRail runs executed in the selected period. Calc: COUNT of runs where created_on or completed_on is in the period. Window: Daily, per sprint, per release. Target: Match planned runs for the cycle; no systematic misses."
      display: hover
  - name: kpi_p13
    type: looker_line
    title: P13 - Test Cases Executed
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P13
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 44
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Total test cases executed (passed, failed, blocked, retest). Calc: SUM(passed_count + failed_count + blocked_count + retest_count). Window: Daily, per sprint, per release. Target: Should align with planned coverage for release / test plan."
      display: hover
  - name: kpi_p14
    type: looker_line
    title: P14 - Pass Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P14
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 50
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of executed test cases that passed. Calc: SUM(passed_count) / SUM(passed_count + failed_count + blocked_count + retest_count). Window: Daily, per sprint, per release. Target: Target for release builds typically >=95% depending on risk."
      display: hover
  - name: kpi_p15
    type: looker_line
    title: P15 - Fail Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P15
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 50
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of executed test cases that failed. Calc: SUM(failed_count) / SUM(passed_count + failed_count + blocked_count + retest_count). Window: Daily, per sprint, per release. Target: Should trend down as release stabilises."
      display: hover
  - name: kpi_p16
    type: looker_line
    title: P16 - Blocked Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P16
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 56
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of executed test cases that are blocked by environment, data or dependencies. Calc: SUM(blocked_count) / SUM(passed_count + failed_count + blocked_count + retest_count). Window: Daily, per sprint, per release. Target: Keep <5% where possible; spikes indicate infra issues."
      display: hover
  - name: kpi_p17
    type: looker_line
    title: P17 - Retest Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P17
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 56
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of executed test cases that required retest. Calc: SUM(retest_count) / SUM(passed_count + failed_count + blocked_count + retest_count). Window: Per sprint, per release. Target: High retest rate may indicate unstable builds or late fixes."
      display: hover
  - name: kpi_p18
    type: looker_line
    title: P18 - Test Coverage (Executed vs Planned)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P18
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 62
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Coverage of planned test cases that were actually executed. Calc: Executed tests / (executed tests + untested_count). Window: Per sprint, per release. Target: Typical gate >=90–95% depending on risk profile."
      display: hover
  - name: kpi_p19
    type: looker_line
    title: P19 - Average Test Run Duration
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P19
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 62
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Average duration of TestRail runs from creation to completion. Calc: Average HOURS between created_on and completed_on for completed runs. Window: Per sprint; rolling 4 weeks. Target: No strict target; watch for anomalies and long tails."
      display: hover
  - name: section_prod
    type: text
    title_text: Production stability
    subtitle_text: Incidents, error load, and user impact
    body_text: ''
    row: 68
    col: 0
    width: 24
    height: 2
  - name: kpi_p22
    type: looker_line
    title: P22 - New Production Errors
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P22
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 70
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Distinct Bugsnag errors first seen in the current period. Calc: COUNT DISTINCT error_id where first_seen date is in the period. Window: Daily, per sprint, per release. Target: Should drop as release matures; spikes after release show regressions."
      display: hover
  - name: kpi_p23
    type: looker_line
    title: P23 - Total Error Events (Live Incident Rate)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P23
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 70
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Total number of error events captured by Bugsnag in the period. Calc: SUM(events) for errors where last_seen is inside the period. Window: Daily, weekly; rolling 30 days. Target: Trend down over time; alerts on deviations from baseline."
      display: hover
  - name: kpi_p24
    type: looker_line
    title: P24 - Users Impacted by Errors
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P24
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 76
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Total number of users affected by Bugsnag errors in the period (approximate). Calc: SUM(users) for errors where last_seen is in the period. Window: Daily, weekly; rolling 30 days. Target: Minimise, especially for high severity issues."
      display: hover
  - name: kpi_p25
    type: looker_line
    title: P25 - Average Error Lifetime
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P25
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 76
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time between first_seen and last_seen for resolved errors. Calc: Average DAYS between first_seen and last_seen for errors marked as fixed or inactive. Window: Rolling 30 days or per release. Target: Shorter lifetimes indicate faster detection & fix rollout."
      display: hover
  - name: kpi_p26
    type: looker_line
    title: P26 - Defects per 100 Test Cases Executed
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P26
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 82
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Ratio of defects found to test cases executed, indicating defect yield. Calc: (Bugs created in period / Executed test cases in period) * 100. Window: Per sprint, per release. Target: Used comparatively across releases and QA Groups."
      display: hover
  - name: kpi_p27
    type: looker_bar
    title: P27 - Production Incidents per Release
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.release
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P27
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.kpi_value desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 82
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Number of high-severity production incidents associated with a release. Calc: COUNT DISTINCT high/critical Bugsnag errors mapped to a release. Window: Per release. Target: Goal: zero or minimal critical incidents per release."
      display: hover
  - name: kpi_p28
    type: looker_bar
    title: P28 - Release Quality Gate Status
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.release
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P28
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.kpi_value desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 88
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Pass/Fail indicator summarising whether a release meets severity thresholds and coverage targets. Calc: Gate PASS if: coverage >= threshold; 0 open Critical; High backlog under limit; SLA compliance above target; incident rate below threshold. Window: Evaluated at each RC and before launch. Target: All launches should meet gate or be explicitly waived."
      display: hover
  - name: section_quality_eff
    type: text
    title_text: Quality efficiency
    subtitle_text: Team/process effectiveness and downstream quality signals
    body_text: ''
    row: 94
    col: 0
    width: 24
    height: 2
  - name: kpi_p29
    type: looker_line
    title: P29 - Hands-on Testing Time % (Team)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P29
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 96
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of QA time spent on hands-on testing activities for each team. Calc: Hands-On hours / total QA hours in the period. Window: Weekly, per sprint, per quarter. Target: Target 75% Hands-On at team level."
      display: hover
  - name: kpi_p30
    type: looker_line
    title: P30 - Non Hands-on Time % (Team)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P30
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 96
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of QA time spent on non hands-on activities (test design, meetings, training, pre-mastering). Calc: Non Hands-On hours / total QA hours in the period. Window: Weekly, per sprint, per quarter. Target: Target around 25% Non Hands-On."
      display: hover
  - name: kpi_p31
    type: looker_line
    title: P31 - Bug Escape Rate (by severity)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P31
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 102
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Share of defects that escape to production, broken down by severity (Blocker/Critical/Major). Calc: (Defects found in production / (Pre-release defects + production defects)) by severity. Window: Per release and weekly. Target: High expectation: 0–2% Blocker/Critical; <4% Majors."
      display: hover
  - name: kpi_p32
    type: looker_line
    title: P32 - Defect Detection Efficiency (DDE)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P32
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 102
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of total defects for a release that were detected before going to production. Calc: Pre-release defects / (Pre-release + post-release defects) * 100. Window: Per release and monthly. Target: High expectation: >90% coverage; minimum acceptable ≥85%."
      display: hover
  - name: kpi_p33
    type: looker_line
    title: P33 - Bug Rejection Rate
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P33
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 108
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of reported bugs that are rejected as not valid (Not a Bug, Won't Fix, Duplicate). Calc: Rejected bugs / total bugs closed in the period. Window: Weekly and per release. Target: High expectation: <5% overall."
      display: hover
  - name: kpi_p34
    type: looker_line
    title: P34 - Bug Report Completeness
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P34
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 108
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of bug reports that meet minimum reproducibility standard (screenshots, logs, steps, build info). Calc: Number of bugs marked as complete / total bugs reported in the period. Window: Weekly. Target: High expectation: >99% of bugs meet completeness standard."
      display: hover
  - name: kpi_p35
    type: looker_line
    title: P35 - Execution Result Accuracy
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P35
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 114
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Accuracy of test results recorded vs actual outcome (how often initial result is later changed). Calc: 1 - (Incorrect or changed results / total executed tests). Window: Per test cycle. Target: High expectation: very high accuracy (≈99%)."
      display: hover
  - name: kpi_p36
    type: looker_line
    title: P36 - Severity Assignment Accuracy
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P36
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 114
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Percentage of bugs whose initial severity matches the final agreed severity. Calc: Correct severity assignments / total bugs, where correct = no change or change within agreed tolerance. Window: Weekly and per release. Target: High expectation: close to 100%; specific tolerance per team."
      display: hover
  - name: kpi_p37
    type: looker_line
    title: P37 - Test Execution Throughput (cases per person‑day)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P37
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 120
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Average number of test cases executed per QA person‑day. Calc: Executed test cases / QA testing hours converted to person‑days. Window: Daily and per test cycle. Target: Target depends on game and complexity; watch trend rather than absolute."
      display: hover
  - name: kpi_p38
    type: looker_line
    title: P38 - Bug Reporting Lead Time
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P38
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 120
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time between discovering an issue and logging it as a bug. Calc: Average minutes from detection to bug creation. Window: Daily. Target: High expectation: very low (for example <15 minutes for most issues)."
      display: hover
  - name: kpi_p39
    type: looker_line
    title: P39 - Fix Verification Cycle Time
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P39
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 126
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time from a fix being ready for QA to verification completed. Calc: Average hours between dev-ready and QA verification completion. Window: Daily and per release. Target: Targets per severity (e.g., same‑day for Critical)."
      display: hover
  - name: kpi_p40
    type: looker_line
    title: P40 - Exploratory Session Reporting Coverage
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P40
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 126
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Coverage and time spent in documented exploratory testing sessions. Calc: Documented exploratory sessions / total exploratory sessions; plus total hours. Window: Weekly. Target: High expectation: near 100% of exploratory sessions documented."
      display: hover
  - name: kpi_p41
    type: looker_line
    title: P41 - Time to Flag
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P41
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 132
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Time to escalate and communicate critical risks/blockers from detection to correct channel. Calc: Average minutes from risk detection to first flag. Window: Daily. Target: Expectation: very quick (for example within same test session)."
      display: hover
  - name: kpi_p42
    type: looker_line
    title: P42 - Response Time SLA (Comms interaction)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P42
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 132
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value": "#2ca02c"
    note:
      text: "Time QA takes to acknowledge and respond to urgent vs general requests in communication channels. Calc: Average response time in minutes, tracked separately for urgent vs general. Window: Weekly. Target: High expectation: <10 min for urgent, <30 min for general requests."
      display: hover
  - name: kpi_p43
    type: looker_line
    title: P43 - Defect Acceptance Ratio (DAR)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P43
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 138
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#2ca02c"
    note:
      text: "Percentage of reported defects that are accepted as valid (not rejected as NAB, Duplicate, Won’t Fix). Calc: Accepted bugs / total bugs closed in the period * 100. Window: Weekly, per sprint, per release. Target: Target >=92%."
      display: hover
  - name: kpi_p44
    type: looker_line
    title: P44 - High Severity Defect Reporting Rate (P0+P1)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P44
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 138
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of total reported defects that are P0 or P1 severity. Calc: (P0 + P1 bugs reported) / total bugs reported * 100. Window: Weekly, per sprint, per release. Target: Target >=25% Depending on The milestone phase."
      display: hover
  - name: kpi_p45
    type: looker_line
    title: P45 - NMI Rate (No-Merge / Not Meaningful Issues)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P45
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 144
    col: 0
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of reported defects classified as NMI (issues that do not require a code fix or merge). Calc: NMI bugs / total bugs closed * 100. Window: Weekly, per sprint. Target: Target <=5%."
      display: hover
  - name: kpi_p46
    type: looker_line
    title: P46 - Defect Leak Rate (Live)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: P46
      qa_kpi_facts.privacy_level: public
    sorts:
    - qa_kpi_facts.metric_date_week
    limit: 500
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    row: 144
    col: 12
    width: 12
    height: 5
    vis_config:
      show_legend: false
      show_x_axis_label: false
      show_y_axis_label: false
      x_axis_gridlines: false
      y_axis_gridlines: true
      show_null_points: true
      interpolation: linear
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of total defects that were first identified in live/production. Calc: Live defects / (pre-release defects + live defects) * 100. Window: Per release; rolling 30 days. Target: Target <=2%."
      display: hover
  description: Leadership-friendly view of QA KPIs (Public). Use filters to slice KPIs; hover tile notes for definitions.
