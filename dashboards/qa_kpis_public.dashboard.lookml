- dashboard: qa_kpis_public
  title: QA KPIs - Public
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
  elements:
  - name: intro_text
    type: text
    title_text: How to use
    body_text: '**Purpose:** Executive view of QA quality, testing throughput, and production stability.

      - Use the top filters to slice by POD / Feature / Release / Sprint / Severity.

      - Hover the **tile note (ⓘ)** for a quick definition of each KPI.

      - Ratio KPIs use **numerator / denominator** when available; otherwise they sum `kpi_value`.'
    row: 0
    col: 0
    width: 24
    height: 4
    subtitle_text: Filters apply to all tiles (Date Range uses metric_ts to avoid DATE/TIMESTAMP errors).
  - name: section_at_a_glance
    type: text
    title_text: At a glance
    subtitle_text: Snapshot + top-level indicators
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
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P5
      qa_kpi_facts.privacy_level: public
    limit: 500
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 6
    col: 0
    width: 8
    height: 3
    note:
      text: Current open defect backlog (snapshot).
      display: hover
  - name: kpi_p6
    type: single_value
    title: P6 - Open Critical & High Defects
    model: panda_qa_metrics
    explore: qa_kpi_facts
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P6
      qa_kpi_facts.privacy_level: public
    limit: 500
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 6
    col: 8
    width: 8
    height: 3
    note:
      text: Current open defects with High/Critical severity (snapshot).
      display: hover
  - name: kpi_p7
    type: single_value
    title: P7 - Average Age of Open Defects
    model: panda_qa_metrics
    explore: qa_kpi_facts
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P7
      qa_kpi_facts.privacy_level: public
    limit: 500
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 6
    col: 16
    width: 8
    height: 3
    note:
      text: Average age of currently open defects (typically in days).
      display: hover
  - name: kpi_p20
    type: single_value
    title: P20 - Active Production Errors
    model: panda_qa_metrics
    explore: qa_kpi_facts
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P20
      qa_kpi_facts.privacy_level: public
    limit: 500
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 10
    col: 0
    width: 8
    height: 3
    note:
      text: Active production errors (current snapshot).
      display: hover
  - name: kpi_p21
    type: single_value
    title: P21 - High/Critical Active Errors
    model: panda_qa_metrics
    explore: qa_kpi_facts
    measures:
    - qa_kpi_facts.kpi_value
    filters:
      qa_kpi_facts.kpi_id: P21
      qa_kpi_facts.privacy_level: public
    limit: 500
    listen:
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      date_range: qa_kpi_facts.metric_ts_date
    row: 10
    col: 8
    width: 8
    height: 3
    note:
      text: Active production errors with High/Critical severity (snapshot).
      display: hover
  - name: at_a_glance_note
    type: text
    title_text: Reading snapshot KPIs
    subtitle_text: ''
    body_text: Snapshot tiles (backlog / active errors) reflect the latest data point within the selected filters.
    row: 10
    col: 16
    width: 8
    height: 3
  - name: section_defects
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
    note:
      text: Weekly count of defects created in the selected filters.
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
    note:
      text: Weekly count of defects closed/resolved.
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
    note:
      text: Weekly count of defects reopened.
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
    note:
      text: Reopen rate over time (percentage).
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
    note:
      text: Average time from defect creation to triage.
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
    note:
      text: Mean time to resolution (MTTR) for defects.
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
    note:
      text: Percent of High/Critical defects meeting the SLA target.
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
    note:
      text: Defects per 100 story points (normalized density).
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
    note:
      text: Test runs executed over time.
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
    note:
      text: Test cases executed over time.
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
    note:
      text: Pass rate over time (percentage).
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
    note:
      text: Fail rate over time (percentage).
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
    note:
      text: Blocked rate over time (percentage).
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
    note:
      text: Retest rate over time (percentage).
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
    note:
      text: Executed vs planned test coverage (percentage).
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
    note:
      text: Average test run duration over time.
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
    note:
      text: New production errors created over time.
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
    note:
      text: Total error events / incident rate over time.
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
    note:
      text: Users impacted by production errors over time.
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
    note:
      text: Average error lifetime over time.
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
    note:
      text: Defects per 100 executed test cases (normalized).
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
    note:
      text: Production incidents grouped by Release (top releases by count).
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
    note:
      text: Quality gate metric grouped by Release (interpretation depends on KPI definition).
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
    note:
      text: Team hands-on testing time share over time (percentage).
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
    note:
      text: Team non hands-on time share over time (percentage).
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
    note:
      text: Bug escape rate over time (by severity) (percentage).
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
    note:
      text: Defect Detection Efficiency (DDE) over time (percentage).
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
    note:
      text: Bug rejection rate over time (percentage).
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
    note:
      text: Bug report completeness over time (percentage).
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
    note:
      text: Execution result accuracy over time.
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
    note:
      text: Severity assignment accuracy over time.
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
    note:
      text: Test execution throughput over time (cases per person‑day).
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
    note:
      text: Bug reporting lead time over time.
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
    note:
      text: Fix verification cycle time over time.
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
    note:
      text: Exploratory session reporting coverage over time.
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
    note:
      text: Time to flag over time.
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
    note:
      text: Response time SLA metric over time (interpretation depends on KPI definition).
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
    note:
      text: Defect Acceptance Ratio (DAR) over time (percentage).
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
    note:
      text: High severity defect reporting rate over time (percentage).
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
    note:
      text: NMI rate (No‑Merge / Not‑Meaningful Issues) over time (percentage).
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
    note:
      text: Defect leak rate over time (percentage).
      display: hover
  description: Leadership-friendly view of QA KPIs (Public). Use filters to slice KPIs; hover tile notes for definitions.
