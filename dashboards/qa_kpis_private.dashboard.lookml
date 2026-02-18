- dashboard: qa_kpis_private
  title: QA KPIs - Private (Leadership / Leads)
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
  - name: qa_user
    title: QA User
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.qa_user
  - name: developer_user
    title: Developer
    type: field_filter
    model: panda_qa_metrics
    explore: qa_kpi_facts
    field: qa_kpi_facts.developer_user
  elements:
  - name: leadership_overview
    type: text
    title_text: Leadership overview
    subtitle_text: Team-level signals (latest week) — use filters to drill into POD/Feature
    body_text: ''
    row: 0
    col: 0
    width: 24
    height: 2
  - name: kpi_r1_team
    type: single_value
    title: R1 - Hands-on Testing Time % (Team avg)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R1
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 2
    col: 0
    width: 8
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#1f77b4"
    note:
      text: "Percentage of each QA engineer's time spent on hands-on testing activities. Calc: Hands-On hours per QA / total logged hours per QA. Window: Weekly, per sprint, per quarter. Target: Target 75% Hands-On per QA; deviations require context."
      display: hover
  - name: kpi_r10_team
    type: single_value
    title: R10 - Test Cases per Hour (Team avg)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R10
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 2
    col: 8
    width: 8
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#1f77b4"
    note:
      text: "Approximate throughput of executed test cases per hour of run time. Calc: Executed test cases / total run duration hours for each QA. Window: Per sprint, per release. Target: Directional only; strongly depends on complexity."
      display: hover
  - name: kpi_r15_team
    type: single_value
    title: R15 - Bug Report Completeness (Team avg)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.metric_date_week
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R15
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 2
    col: 16
    width: 8
    height: 4
    vis_config:
      show_single_value_title: true
      show_comparison: true
      comparison_type: value
      custom_color_enabled: true
      custom_color: "#1f77b4"
    note:
      text: "Percentage of a QA's bug reports that meet the reproducibility standard (screens, logs, steps, build info). Calc: Complete bugs reported by QA / total bugs reported by QA. Window: Weekly, per release. Target: High expectation: >99% per QA."
      display: hover
  - name: intro_text
    type: text
    title_text: How to use
    body_text: '**Purpose:** Operational QA KPIs by QA and developer for coaching & planning.

      - Use filters to slice by POD / Feature / Release / Sprint / Severity, plus **QA User** and **Developer**.

      - Hover the **tile note (ⓘ)** for definitions.

      - Ratio KPIs use **numerator / denominator** when available; otherwise they sum `kpi_value`.'
    row: 0
    col: 0
    width: 24
    height: 4
    subtitle_text: Private dashboard for Leads (per‑person / sensitive slices).
  - name: section_time
    type: text
    title_text: Time allocation
    subtitle_text: Hands‑on vs non hands‑on mix
    body_text: ''
    row: 6
    col: 0
    width: 24
    height: 2
  - name: kpi_r1
    type: looker_bar
    title: R1 - Hands-on Testing Time % per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R1
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 8
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#1f77b4"
    note:
      text: "Percentage of each QA engineer's time spent on hands-on testing activities. Calc: Hands-On hours per QA / total logged hours per QA. Window: Weekly, per sprint, per quarter. Target: Target 75% Hands-On per QA; deviations require context."
      display: hover
  - name: kpi_r2
    type: looker_bar
    title: R2 - Non Hands-on Time % per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R2
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 8
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of each QA engineer's time spent on non hands-on activities (test design, meetings, training, pre-mastering). Calc: Non Hands-On hours per QA / total logged hours per QA. Window: Weekly, per sprint, per quarter. Target: Target around 25% Non Hands-On per QA."
      display: hover
  - name: kpi_r3
    type: looker_bar
    title: R3 — Hands-on Hours per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R3
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 15
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#1f77b4"
    note:
      text: "Hands-on hours per QA across activity types (test execution, regression, playtest, live testing, destructive, performance, etc.). Calc: Sum of hands-on hours per QA per activity category. Window: Per sprint, per quarter. Target: No strict target; used to align focus with priorities."
      display: hover
  - name: kpi_r4
    type: looker_bar
    title: R4 — Non Hands-on Hours per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R4
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 15
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Non hands-on hours per QA across activities (test case creation, meetings, training, pre-mastering). Calc: Sum of non hands-on hours per QA per activity category. Window: Per sprint, per quarter. Target: Identify people overloaded with meetings / coordination."
      display: hover
  - name: kpi_r5
    type: looker_bar
    title: R5 - Deviation from 75/25 Hands-on Mix per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R5
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 22
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Degree to which each QA engineer diverges from the target 75% hands-on / 25% non hands-on split. Calc: Hands-On % - 75% and Non Hands-On % - 25% per QA. Window: Per sprint, per quarter. Target: +/-10 percentage points used as soft threshold."
      display: hover
  - name: section_exec
    type: text
    title_text: Test execution
    subtitle_text: Volume, throughput, and outcomes (per QA)
    body_text: ''
    row: 29
    col: 0
    width: 24
    height: 2
  - name: kpi_r6
    type: looker_bar
    title: R6 - Test Cases Executed per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R6
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 31
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#1f77b4"
    note:
      text: "Number of test cases executed by each QA engineer. Calc: For runs assigned to the QA: SUM(passed + failed + blocked + retest). Window: Per sprint, per release. Target: Used for capacity planning; not a ranking metric by itself."
      display: hover
  - name: kpi_r10
    type: looker_bar
    title: R10 - Test Cases per Hour per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R10
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 31
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#1f77b4"
    note:
      text: "Approximate throughput of executed test cases per hour of run time. Calc: Executed test cases / total run duration hours for each QA. Window: Per sprint, per release. Target: Directional only; strongly depends on complexity."
      display: hover
  - name: kpi_r7
    type: looker_bar
    title: R7 - Pass Rate per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R7
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 38
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#1f77b4"
    note:
      text: "Pass rate of test cases executed by each QA engineer. Calc: SUM(passed) / SUM(passed + failed + blocked + retest) for each QA. Window: Per sprint, per release. Target: Interpreted with caution; depends on type of work executed."
      display: hover
  - name: kpi_r8
    type: looker_bar
    title: R8 - Fail Rate per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R8
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 38
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of executed test cases that failed for each QA engineer. Calc: SUM(failed) / SUM(passed + failed + blocked + retest) for each QA. Window: Per sprint, per release. Target: Higher fail rate can indicate testing of riskier features."
      display: hover
  - name: kpi_r9
    type: looker_bar
    title: R9 - Average Test Run Duration per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R9
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 45
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average duration of runs executed by each QA engineer. Calc: Average HOURS between created_on and completed_on for completed runs owned by each QA. Window: Rolling 4 weeks; per sprint. Target: Identify extreme values for coaching and planning."
      display: hover
  - name: section_bug_quality
    type: text
    title_text: Bug reporting quality
    subtitle_text: Reporting volume, yield, and quality (per QA)
    body_text: ''
    row: 52
    col: 0
    width: 24
    height: 2
  - name: kpi_r11
    type: looker_bar
    title: R11 - Defects Reported per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R11
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 54
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#1f77b4"
    note:
      text: "Number of Jira defects created where the reporter is a specific QA engineer. Calc: COUNT of Bug issues with reporter = QA and created in period. Window: Per sprint, per release. Target: Used to understand distribution of defect discovery."
      display: hover
  - name: kpi_r12
    type: looker_bar
    title: R12 - High/Critical Defects Reported per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R12
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 54
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Number of high severity defects raised by each QA engineer. Calc: COUNT of Bug issues where reporter = QA AND priority in ('Blocker','Critical','High'). Window: Per sprint, per release. Target: Highlights focus on high‑impact issues."
      display: hover
  - name: kpi_r13
    type: looker_bar
    title: R13 - Defect Yield per QA (Defects per 100 Executed Tests)
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R13
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 61
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#d62728"
    note:
      text: "Ratio of defects logged by each QA relative to executed test cases. Calc: (Defects reported by QA / Test cases executed by QA) * 100. Window: Per sprint, per release. Target: Interpret relative to feature risk and assignment."
      display: hover
  - name: kpi_r14
    type: looker_bar
    title: R14 - Reopen Rate for Defects Reported by QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R14
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 61
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of defects originally reported by a QA that were reopened after closure. Calc: For issues with reporter = QA, reopened defects / closed defects. Window: Rolling 3–6 months. Target: Lower is better; high values may indicate unclear repro or acceptance criteria."
      display: hover
  - name: kpi_r15
    type: looker_bar
    title: R15 - Bug Report Completeness per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R15
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 68
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#1f77b4"
    note:
      text: "Percentage of a QA's bug reports that meet the reproducibility standard (screens, logs, steps, build info). Calc: Complete bugs reported by QA / total bugs reported by QA. Window: Weekly, per release. Target: High expectation: >99% per QA."
      display: hover
  - name: kpi_r16
    type: looker_bar
    title: R16 - Bug Rejection Rate per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R16
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 68
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of a QA's reported bugs that are rejected as Not a Bug / Won't Fix / Duplicate. Calc: Rejected bugs for QA / total bugs closed for QA. Window: Weekly and per release. Target: Expectation <5% for most QAs."
      display: hover
  - name: kpi_r17
    type: looker_bar
    title: R17 - Severity Assignment Accuracy per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R17
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 75
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#1f77b4"
    note:
      text: "Accuracy of initial severity assigned by QA compared to final agreed severity. Calc: Correct initial severity assignments / total bugs reported by QA. Window: Weekly and per release. Target: High expectation: near 100% for experienced QAs."
      display: hover
  - name: section_cycle
    type: text
    title_text: Cycle time & comms
    subtitle_text: Lead times and response/flagging behavior (per QA)
    body_text: ''
    row: 82
    col: 0
    width: 24
    height: 2
  - name: kpi_r18
    type: looker_bar
    title: R18 - Bug Reporting Lead Time per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R18
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 84
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time each QA takes from observing an issue to logging the Jira defect. Calc: Average minutes from detection marker to bug creation. Window: Daily and per sprint. Target: Expectation: very low, especially during focused testing sessions."
      display: hover
  - name: kpi_r19
    type: looker_bar
    title: R19 - Time to Flag per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R19
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 84
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Time from detecting a critical risk/blocker to first visible escalation/flag in communication channels. Calc: Average minutes per QA from detection to flag. Window: Daily. Target: Expectation: escalate within same testing session."
      display: hover
  - name: kpi_r20
    type: looker_bar
    title: R20 - Response Time SLA per QA
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.qa_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R20
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 91
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#1f77b4"
    note:
      text: "Average time for each QA to acknowledge urgent vs general requests in comms channels. Calc: Separate averages for urgent and general messages per QA. Window: Weekly. Target: Expect <10 minutes for urgent, <30 minutes for general."
      display: hover
  - name: section_dev
    type: text
    title_text: Developer responsiveness
    subtitle_text: Developer-facing operational KPIs
    body_text: ''
    row: 98
    col: 0
    width: 24
    height: 2
  - name: kpi_r21
    type: looker_bar
    title: R21 - Bugs Assigned per Developer
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.developer_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R21
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value desc
    limit: 50
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
      date_range: qa_kpi_facts.metric_ts_date
    row: 100
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#1f77b4"
    note:
      text: "Number of defect tickets assigned to each developer. Calc: COUNT of Bug issues where assignee = developer and created in period or currently assigned. Window: Per sprint, per month. Target: No target; used to ensure fair distribution and to spot overload."
      display: hover
  - name: kpi_r22
    type: looker_bar
    title: R22 - Average Time to Resolution per Developer
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.developer_user
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: R22
      qa_kpi_facts.privacy_level: private
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
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 100
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value": "#ff7f0e"
    note:
      text: "Average time developers take to resolve bugs assigned to them. Calc: Average DAYS between created and resolutiondate for bugs resolved by each developer. Window: Rolling 3–6 months. Target: Context dependent; used for coaching and support."
      display: hover
  - name: kpi_r23
    type: looker_bar
    title: R23 - Reopen Rate per Developer
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.developer_user
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R23
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 107
    col: 0
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#d62728"
    note:
      text: "Percentage of bugs fixed by a developer that were later reopened. Calc: Reopened bugs / total bugs resolved by that developer. Window: Rolling 3–6 months. Target: Lower is better; high values indicate need for deeper testing or design review."
      display: hover
  - name: kpi_r24
    type: looker_bar
    title: R24 - QA Capacity vs Expectation per POD
    model: panda_qa_metrics
    explore: qa_kpi_facts
    dimensions:
    - qa_kpi_facts.pod
    measures:
    - qa_kpi_facts.kpi_value_percent
    filters:
      qa_kpi_facts.kpi_id: R24
      qa_kpi_facts.privacy_level: private
    sorts:
    - qa_kpi_facts.kpi_value_percent desc
    limit: 50
    listen:
      date_range: qa_kpi_facts.metric_ts_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    row: 107
    col: 12
    width: 12
    height: 6
    vis_config:
      show_legend: false
      show_value_labels: true
      orientation: horizontal
      x_axis_gridlines: false
      y_axis_gridlines: false
      series_colors:
        "qa_kpi_facts.kpi_value_percent": "#9467bd"
    note:
      text: "Comparison of actual QA hours (Dev vs External) vs expected hours from OS expectations for each POD. Calc: Actual hours / expected hours, reported as % and variance. Window: Per sprint, per month, per quarter. Target: Identify overloaded or underutilised PODs; target around 100%."
      display: hover
  description: Leadership-friendly view of QA KPIs (Private / Leads). Contains per-person breakdowns.
