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
    row: 4
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
    row: 6
    col: 0
    width: 12
    height: 6
    note:
      text: Hands-on testing time share per QA (percentage).
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
    row: 6
    col: 12
    width: 12
    height: 6
    note:
      text: Non hands-on time share per QA (percentage).
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
    row: 13
    col: 0
    width: 12
    height: 6
    note:
      text: Total hands-on testing hours per QA.
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
    row: 13
    col: 12
    width: 12
    height: 6
    note:
      text: Total non hands-on hours per QA.
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
    row: 20
    col: 0
    width: 12
    height: 6
    note:
      text: Deviation from the 75/25 hands‑on vs non hands‑on target mix (percentage points).
      display: hover
  - name: section_exec
    type: text
    title_text: Test execution
    subtitle_text: Volume, throughput, and outcomes (per QA)
    body_text: ''
    row: 27
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
    row: 29
    col: 0
    width: 12
    height: 6
    note:
      text: Test cases executed per QA (volume).
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
    row: 29
    col: 12
    width: 12
    height: 6
    note:
      text: Test cases executed per hour per QA (throughput).
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
    row: 36
    col: 0
    width: 12
    height: 6
    note:
      text: Pass rate per QA (percentage).
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
    row: 36
    col: 12
    width: 12
    height: 6
    note:
      text: Fail rate per QA (percentage).
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
    row: 43
    col: 0
    width: 12
    height: 6
    note:
      text: Average test run duration per QA.
      display: hover
  - name: section_bug_quality
    type: text
    title_text: Bug reporting quality
    subtitle_text: Reporting volume, yield, and quality (per QA)
    body_text: ''
    row: 50
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
    row: 52
    col: 0
    width: 12
    height: 6
    note:
      text: Defects reported per QA.
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
    row: 52
    col: 12
    width: 12
    height: 6
    note:
      text: High/Critical defects reported per QA.
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
    row: 59
    col: 0
    width: 12
    height: 6
    note:
      text: Defects per 100 executed tests per QA (normalized yield).
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
    row: 59
    col: 12
    width: 12
    height: 6
    note:
      text: Reopen rate for defects reported by QA (percentage).
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
    row: 66
    col: 0
    width: 12
    height: 6
    note:
      text: Bug report completeness per QA (percentage).
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
    row: 66
    col: 12
    width: 12
    height: 6
    note:
      text: Bug rejection rate per QA (percentage).
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
    row: 73
    col: 0
    width: 12
    height: 6
    note:
      text: Severity assignment accuracy per QA.
      display: hover
  - name: section_cycle
    type: text
    title_text: Cycle time & comms
    subtitle_text: Lead times and response/flagging behavior (per QA)
    body_text: ''
    row: 80
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
    row: 82
    col: 0
    width: 12
    height: 6
    note:
      text: Bug reporting lead time per QA.
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
    row: 82
    col: 12
    width: 12
    height: 6
    note:
      text: Time to flag per QA.
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
    row: 89
    col: 0
    width: 12
    height: 6
    note:
      text: Response time SLA metric per QA.
      display: hover
  - name: section_dev
    type: text
    title_text: Developer responsiveness
    subtitle_text: Developer-facing operational KPIs
    body_text: ''
    row: 96
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
    row: 98
    col: 0
    width: 12
    height: 6
    note:
      text: Bugs assigned per developer (volume).
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
    row: 98
    col: 12
    width: 12
    height: 6
    note:
      text: Average time to resolution per developer.
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
    row: 105
    col: 0
    width: 12
    height: 6
    note:
      text: Reopen rate per developer (percentage).
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
    row: 105
    col: 12
    width: 12
    height: 6
    note:
      text: QA capacity vs expectation per POD (ratio/percentage).
      display: hover
  description: Leadership-friendly view of QA KPIs (Private / Leads). Contains per-person breakdowns.
