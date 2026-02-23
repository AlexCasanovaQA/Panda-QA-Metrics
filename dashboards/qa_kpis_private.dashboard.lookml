- dashboard: qa_kpis_private
  title: QA KPIs - Private (Leads)
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
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.pod
    - name: feature
      title: Feature
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.feature
    - name: release
      title: Release
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.release
    - name: sprint
      title: Sprint
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.sprint
    - name: severity
      title: Severity
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.severity
    - name: priority
      title: Priority
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.priority_label
    - name: qa_user
      title: QA User
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.qa_user
    - name: developer
      title: Developer
      type: field_filter
      model: panda_qa_metrics
      explore: panda_qa_kpi_facts
      field: panda_qa_kpi_facts.developer_user
  elements:
  - name: intro
    type: text
    title_text: "How to use"
    body_text: "Private dashboard adds per-QA and per-Developer breakdowns. Use filters to slice, and hover tiles for definition + calculation."
    row: 0
    col: 0
    width: 24
    height: 3
  - name: sec_exec
    type: text
    title_text: "Team Overview (Top Priority)"
    body_text: "High-signal KPIs across QA and Dev. Sources: Jira / TestRail / Manual."
    row: 3
    col: 0
    width: 24
    height: 2
  - name: exec_r11
    type: looker_bar
    title: R11 - Defects Reported per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R11"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of Jira defects created where the reporter is a specific QA engineer.\nHow it's calculated: COUNT of Bug issues with reporter = QA and created in period.\nGranularity: Per QA / sprint / release\nTime window: Per sprint, per release\nTarget/threshold: Used to understand distribution of defect discovery.\nOwner: POD QA Lead\nNotes: Bar chart per QA; separate Dev QA vs Amber/GSQA."
    row: 5
    col: 0
    width: 12
    height: 6
  - name: exec_r6
    type: looker_bar
    title: R6 - Test Cases Executed per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R6"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Number of test cases executed by each QA engineer.\nHow it's calculated: For runs assigned to the QA: SUM(passed + failed + blocked + retest).\nGranularity: Per QA / sprint / milestone\nTime window: Per sprint, per release\nTarget/threshold: Used for capacity planning; not a ranking metric by itself.\nOwner: POD QA Lead\nNotes: Histogram or bar per QA; separate Dev QA vs Amber/GSQA."
    row: 5
    col: 12
    width: 12
    height: 6
  - name: exec_r21
    type: looker_bar
    title: R21 - Bugs Assigned per Developer
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.developer_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R21"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of defect tickets assigned to each developer.\nHow it's calculated: COUNT of Bug issues where assignee = developer and created in period or currently assigned.\nGranularity: Per developer / POD\nTime window: Per sprint, per month\nTarget/threshold: No target; used to ensure fair distribution and to spot overload.\nOwner: Engineering Manager\nNotes: Table by developer; combine with R22 and R23."
    row: 11
    col: 0
    width: 12
    height: 6
  - name: exec_r22
    type: looker_bar
    title: R22 - Average Time to Resolution per Developer
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.developer_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R22"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Average time developers take to resolve bugs assigned to them.\nHow it's calculated: Average DAYS between created and resolutiondate for bugs resolved by each developer.\nGranularity: Per developer / POD\nTime window: Rolling 3–6 months\nTarget/threshold: Context dependent; used for coaching and support.\nOwner: Engineering Manager\nNotes: Box plot by team; never shared outside eng leadership."
    row: 11
    col: 12
    width: 12
    height: 6
  - name: sec_0
    type: text
    title_text: "QA Time Allocation (Manual)"
    body_text: "Hover a tile for definition and calculation."
    row: 17
    col: 0
    width: 24
    height: 2
  - name: r1
    type: looker_bar
    title: R1 - Hands-on Testing Time % per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R1"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Percentage of each QA engineer's time spent on hands-on testing activities.\nHow it's calculated: Hands-On hours per QA / total logged hours per QA.\nGranularity: Per QA / POD / QA Group\nTime window: Weekly, per sprint, per quarter\nTarget/threshold: Target 75% Hands-On per QA; deviations require context.\nOwner: QA Manager / POD QA Lead\nNotes: Table with conditional formatting; filter by QA Group (Dev vs Amber/GSQA)."
    row: 19
    col: 0
    width: 12
    height: 6
  - name: r2
    type: looker_bar
    title: R2 - Non Hands-on Time % per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R2"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Percentage of each QA engineer's time spent on non hands-on activities (test design, meetings, training, pre-mastering).\nHow it's calculated: Non Hands-On hours per QA / total logged hours per QA.\nGranularity: Per QA / POD / QA Group\nTime window: Weekly, per sprint, per quarter\nTarget/threshold: Target around 25% Non Hands-On per QA.\nOwner: QA Manager / POD QA Lead\nNotes: Used together with R1 as 100% stacked bar per QA."
    row: 19
    col: 12
    width: 12
    height: 6
  - name: r3
    type: looker_bar
    title: R3 - Hands-on Hours by Activity per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R3"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Hands-on hours per QA across activity types (test execution, regression, playtest, live testing, destructive, performance, etc.).\nHow it's calculated: Sum of hands-on hours per QA per activity category.\nGranularity: Per QA / POD / activity\nTime window: Per sprint, per quarter\nTarget/threshold: No strict target; used to align focus with priorities.\nOwner: QA Manager\nNotes: Stacked bars; aggregated view can be used for POD‑level planning."
    row: 25
    col: 0
    width: 12
    height: 6
  - name: r4
    type: looker_bar
    title: R4 - Non Hands-on Hours by Activity per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R4"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Non hands-on hours per QA across activities (test case creation, meetings, training, pre-mastering).\nHow it's calculated: Sum of non hands-on hours per QA per activity category.\nGranularity: Per QA / POD / activity\nTime window: Per sprint, per quarter\nTarget/threshold: Identify people overloaded with meetings / coordination.\nOwner: QA Manager\nNotes: Stacked bar; use filters per POD or QA Group."
    row: 25
    col: 12
    width: 12
    height: 6
  - name: r5
    type: looker_bar
    title: R5 - Deviation from 75/25 Hands-on Mix per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R5"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Degree to which each QA engineer diverges from the target 75% hands-on / 25% non hands-on split.\nHow it's calculated: Hands-On % - 75% and Non Hands-On % - 25% per QA.\nGranularity: Per QA\nTime window: Per sprint, per quarter\nTarget/threshold: +/-10 percentage points used as soft threshold.\nOwner: QA Manager\nNotes: Bar chart deviation; helps balance focus and responsibilities."
    row: 31
    col: 0
    width: 12
    height: 6
  - name: sec_1
    type: text
    title_text: "QA Execution (TestRail)"
    body_text: "Hover a tile for definition and calculation."
    row: 37
    col: 0
    width: 24
    height: 2
  - name: r6
    type: looker_bar
    title: R6 - Test Cases Executed per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R6"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Number of test cases executed by each QA engineer.\nHow it's calculated: For runs assigned to the QA: SUM(passed + failed + blocked + retest).\nGranularity: Per QA / sprint / milestone\nTime window: Per sprint, per release\nTarget/threshold: Used for capacity planning; not a ranking metric by itself.\nOwner: POD QA Lead\nNotes: Histogram or bar per QA; separate Dev QA vs Amber/GSQA."
    row: 39
    col: 0
    width: 12
    height: 6
  - name: r7
    type: looker_bar
    title: R7 - Pass Rate per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R7"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Pass rate of test cases executed by each QA engineer.\nHow it's calculated: SUM(passed) / SUM(passed + failed + blocked + retest) for each QA.\nGranularity: Per QA / sprint / release\nTime window: Per sprint, per release\nTarget/threshold: Interpreted with caution; depends on type of work executed.\nOwner: POD QA Lead\nNotes: Used alongside R8 and R13, not in isolation."
    row: 39
    col: 12
    width: 12
    height: 6
  - name: r8
    type: looker_bar
    title: R8 - Fail Rate per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R8"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Percentage of executed test cases that failed for each QA engineer.\nHow it's calculated: SUM(failed) / SUM(passed + failed + blocked + retest) for each QA.\nGranularity: Per QA / sprint / release\nTime window: Per sprint, per release\nTarget/threshold: Higher fail rate can indicate testing of riskier features.\nOwner: POD QA Lead\nNotes: Scatter plot vs R6 to see who works on most defect‑prone areas."
    row: 45
    col: 0
    width: 12
    height: 6
  - name: r9
    type: looker_bar
    title: R9 - Average Test Run Duration per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R9"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Average duration of runs executed by each QA engineer.\nHow it's calculated: Average HOURS between created_on and completed_on for completed runs owned by each QA.\nGranularity: Per QA / sprint / suite\nTime window: Rolling 4 weeks; per sprint\nTarget/threshold: Identify extreme values for coaching and planning.\nOwner: POD QA Lead\nNotes: Box plots per QA and per suite type."
    row: 45
    col: 12
    width: 12
    height: 6
  - name: r10
    type: looker_bar
    title: R10 - Test Cases per Hour per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R10"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: TestRail + time tracking\nDefinition: Approximate throughput of executed test cases per hour of run time.\nHow it's calculated: Executed test cases / total run duration hours for each QA.\nGranularity: Per QA / sprint\nTime window: Per sprint, per release\nTarget/threshold: Directional only; strongly depends on complexity.\nOwner: QA Manager\nNotes: Scatter plot: throughput vs defect yield (R13)."
    row: 51
    col: 0
    width: 12
    height: 6
  - name: sec_2
    type: text
    title_text: "Defects Quality (Jira)"
    body_text: "Hover a tile for definition and calculation."
    row: 57
    col: 0
    width: 24
    height: 2
  - name: r11
    type: looker_bar
    title: R11 - Defects Reported per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R11"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of Jira defects created where the reporter is a specific QA engineer.\nHow it's calculated: COUNT of Bug issues with reporter = QA and created in period.\nGranularity: Per QA / sprint / release\nTime window: Per sprint, per release\nTarget/threshold: Used to understand distribution of defect discovery.\nOwner: POD QA Lead\nNotes: Bar chart per QA; separate Dev QA vs Amber/GSQA."
    row: 59
    col: 0
    width: 12
    height: 6
  - name: r12
    type: looker_bar
    title: R12 - High/Critical Defects Reported per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R12"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of high severity defects raised by each QA engineer.\nHow it's calculated: COUNT of Bug issues where reporter = QA AND priority in ('Blocker','Critical','High').\nGranularity: Per QA / sprint / release\nTime window: Per sprint, per release\nTarget/threshold: Highlights focus on high‑impact issues.\nOwner: POD QA Lead\nNotes: Stacked bar by severity; used alongside R11."
    row: 59
    col: 12
    width: 12
    height: 6
  - name: r13
    type: looker_bar
    title: R13 - Defect Yield per QA (Defects per 100 Executed Tests)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R13"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira + TestRail\nDefinition: Ratio of defects logged by each QA relative to executed test cases.\nHow it's calculated: (Defects reported by QA / Test cases executed by QA) * 100.\nGranularity: Per QA / sprint / release\nTime window: Per sprint, per release\nTarget/threshold: Interpret relative to feature risk and assignment.\nOwner: QA Manager\nNotes: Scatter plot vs R10 or vs complexity measure."
    row: 65
    col: 0
    width: 12
    height: 6
  - name: r14
    type: looker_bar
    title: R14 - Reopen Rate for Defects Reported by QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R14"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of defects originally reported by a QA that were reopened after closure.\nHow it's calculated: For issues with reporter = QA, reopened defects / closed defects.\nGranularity: Per QA / POD\nTime window: Rolling 3–6 months\nTarget/threshold: Lower is better; high values may indicate unclear repro or acceptance criteria.\nOwner: QA Manager\nNotes: Trend per QA; aggregated anonymised views for broader sharing."
    row: 65
    col: 12
    width: 12
    height: 6
  - name: r15
    type: looker_bar
    title: R15 - Bug Report Completeness per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R15"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of a QA's bug reports that meet the reproducibility standard (screens, logs, steps, build info).\nHow it's calculated: Complete bugs reported by QA / total bugs reported by QA.\nGranularity: Per QA / POD\nTime window: Weekly, per release\nTarget/threshold: High expectation: >99% per QA.\nOwner: QA Manager\nNotes: Bar chart per QA; training focus for lower values."
    row: 71
    col: 0
    width: 12
    height: 6
  - name: r16
    type: looker_bar
    title: R16 - Bug Rejection Rate per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R16"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of a QA's reported bugs that are rejected as Not a Bug / Won't Fix / Duplicate.\nHow it's calculated: Rejected bugs for QA / total bugs closed for QA.\nGranularity: Per QA / sprint / release\nTime window: Weekly and per release\nTarget/threshold: Expectation <5% for most QAs.\nOwner: QA Manager\nNotes: Used carefully in 1:1s; combine with R15."
    row: 71
    col: 12
    width: 12
    height: 6
  - name: sec_3
    type: text
    title_text: "QA Behaviour & Process"
    body_text: "Hover a tile for definition and calculation."
    row: 77
    col: 0
    width: 24
    height: 2
  - name: r17
    type: looker_bar
    title: R17 - Severity Assignment Accuracy per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R17"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Accuracy of initial severity assigned by QA compared to final agreed severity.\nHow it's calculated: Correct initial severity assignments / total bugs reported by QA.\nGranularity: Per QA / POD\nTime window: Weekly and per release\nTarget/threshold: High expectation: near 100% for experienced QAs.\nOwner: QA Manager\nNotes: Bar chart per QA; help align severity guidelines with reality."
    row: 79
    col: 0
    width: 12
    height: 6
  - name: r18
    type: looker_bar
    title: R18 - Bug Reporting Lead Time per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R18"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking + Jira\nDefinition: Average time each QA takes from observing an issue to logging the Jira defect.\nHow it's calculated: Average minutes from detection marker to bug creation.\nGranularity: Per QA / POD\nTime window: Daily and per sprint\nTarget/threshold: Expectation: very low, especially during focused testing sessions.\nOwner: QA Manager\nNotes: Used primarily for OS coaching; approximate at first via manual logging."
    row: 79
    col: 12
    width: 12
    height: 6
  - name: r19
    type: looker_bar
    title: R19 - Time to Flag per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R19"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking + comms tools\nDefinition: Time from detecting a critical risk/blocker to first visible escalation/flag in communication channels.\nHow it's calculated: Average minutes per QA from detection to flag.\nGranularity: Per QA / POD\nTime window: Daily\nTarget/threshold: Expectation: escalate within same testing session.\nOwner: QA Manager / Production\nNotes: Supports postmortems when issues were flagged late."
    row: 85
    col: 0
    width: 12
    height: 6
  - name: r20
    type: looker_bar
    title: R20 - Response Time SLA per QA
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.qa_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R20"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Comms tools + time tracking\nDefinition: Average time for each QA to acknowledge urgent vs general requests in comms channels.\nHow it's calculated: Separate averages for urgent and general messages per QA.\nGranularity: Per QA / POD\nTime window: Weekly\nTarget/threshold: Expect <10 minutes for urgent, <30 minutes for general.\nOwner: QA Manager\nNotes: Used in conjunction with team‑level P42; not exposed publicly per person."
    row: 85
    col: 12
    width: 12
    height: 6
  - name: sec_4
    type: text
    title_text: "Developer Impact (Jira)"
    body_text: "Hover a tile for definition and calculation."
    row: 91
    col: 0
    width: 24
    height: 2
  - name: r21
    type: looker_bar
    title: R21 - Bugs Assigned per Developer
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.developer_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R21"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of defect tickets assigned to each developer.\nHow it's calculated: COUNT of Bug issues where assignee = developer and created in period or currently assigned.\nGranularity: Per developer / POD\nTime window: Per sprint, per month\nTarget/threshold: No target; used to ensure fair distribution and to spot overload.\nOwner: Engineering Manager\nNotes: Table by developer; combine with R22 and R23."
    row: 93
    col: 0
    width: 12
    height: 6
  - name: r22
    type: looker_bar
    title: R22 - Average Time to Resolution per Developer
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.developer_user
    measures:
      - panda_qa_kpi_facts.kpi_value
    sorts:
      - panda_qa_kpi_facts.kpi_value desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R22"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Average time developers take to resolve bugs assigned to them.\nHow it's calculated: Average DAYS between created and resolutiondate for bugs resolved by each developer.\nGranularity: Per developer / POD\nTime window: Rolling 3–6 months\nTarget/threshold: Context dependent; used for coaching and support.\nOwner: Engineering Manager\nNotes: Box plot by team; never shared outside eng leadership."
    row: 93
    col: 12
    width: 12
    height: 6
  - name: r23
    type: looker_bar
    title: R23 - Reopen Rate per Developer
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.developer_user
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    sorts:
      - panda_qa_kpi_facts.kpi_value_percent desc
    filters:
      panda_qa_kpi_facts.kpi_id: "R23"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of bugs fixed by a developer that were later reopened.\nHow it's calculated: Reopened bugs / total bugs resolved by that developer.\nGranularity: Per developer / POD\nTime window: Rolling 3–6 months\nTarget/threshold: Lower is better; high values indicate need for deeper testing or design review.\nOwner: Engineering Manager\nNotes: Trend chart; used in team reviews."
    row: 99
    col: 0
    width: 12
    height: 6
  - name: sec_5
    type: text
    title_text: "Capacity & Staffing (Manual)"
    body_text: "Hover a tile for definition and calculation."
    row: 105
    col: 0
    width: 24
    height: 2
  - name: r24
    type: single_value
    title: R24 - QA Capacity vs Expectation per POD
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "R24"
      panda_qa_kpi_facts.privacy_level: "private"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
      qa_user: panda_qa_kpi_facts.qa_user
      developer: panda_qa_kpi_facts.developer_user
    note_display: hover
    note_text: "Source: Time tracking + OS Expectations sheet\nDefinition: Comparison of actual QA hours (Dev vs External) vs expected hours from OS expectations for each POD.\nHow it's calculated: Actual hours / expected hours, reported as % and variance.\nGranularity: Per POD / QA Group / site\nTime window: Per sprint, per month, per quarter\nTarget/threshold: Identify overloaded or underutilised PODs; target around 100%.\nOwner: QA Director / Production\nNotes: Variance bar or waterfall chart; basis for staffing and vendor decisions."
    row: 107
    col: 0
    width: 12
    height: 4
