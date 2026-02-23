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
  elements:
  - name: intro
    type: text
    title_text: "How to use"
    body_text: "Use filters to slice KPIs. Public dashboard shows public KPIs only. Use the Private dashboard for per-QA and per-Developer breakdowns. Hover any tile to see definition + calculation."
    row: 0
    col: 0
    width: 24
    height: 3
  - name: sec_exec
    type: text
    title_text: "Executive Overview (Top Priority)"
    body_text: "High-signal KPIs for leadership: defects, MTTR/SLA, quality rates, and production stability. Sources: Jira / TestRail / BugSnag / Manual."
    row: 3
    col: 0
    width: 24
    height: 2
  - name: exec_p6
    type: single_value
    title: P6 - Open Critical & High Defects
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P6"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of unresolved Critical and High priority defects.\nHow it's calculated: COUNT of Bug issues where priority in ('Blocker','Critical','High') and resolutiondate IS NULL.\nGranularity: Per POD / feature / release / game\nTime window: Snapshot at end of week / sprint / release\nTarget/threshold: Target 0 open Critical at release; High below agreed limit per feature.\nOwner: POD QA Lead / Engineering Manager\nNotes: KPI tiles per severity; used in release gates and alerts."
    row: 5
    col: 0
    width: 6
    height: 4
  - name: exec_p10
    type: single_value
    title: P10 - Time to Resolution (MTTR)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P10"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Average time from defect creation until resolution.\nHow it's calculated: Average DAYS between created and resolutiondate for bugs resolved in period.\nGranularity: Per POD / feature / priority\nTime window: Per sprint; rolling 4 and 12 weeks\nTarget/threshold: Critical issues resolved within agreed SLA (for example <3 days).\nOwner: Engineering Manager / QA Lead\nNotes: Trend line by severity; show P95 as additional series."
    row: 5
    col: 6
    width: 6
    height: 4
  - name: exec_p11
    type: single_value
    title: P11 - SLA Compliance for Critical/High Defects
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P11"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of Critical/High defects resolved within the agreed resolution SLA.\nHow it's calculated: Resolved Critical/High bugs within SLA window / total Critical/High resolved in period.\nGranularity: Per POD / release / sprint\nTime window: Per sprint; rolling 4 weeks\nTarget/threshold: Target >=95% for Critical, >=90% for High.\nOwner: Engineering Manager / QA Director\nNotes: Gauge or bar by POD; feed into quality gate."
    row: 5
    col: 12
    width: 6
    height: 4
  - name: exec_p21
    type: single_value
    title: P21 - High/Critical Active Errors
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P21"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Number of active production errors with high severity.\nHow it's calculated: COUNT DISTINCT error_id where severity in ('error','critical') AND status != 'fixed'.\nGranularity: Per project / platform / release\nTime window: Daily snapshot; weekly trend\nTarget/threshold: Aim for zero open critical errors.\nOwner: LiveOps QA Lead / Eng Manager\nNotes: Dedicated tile and alerting; used in Go/No-Go for live promotions."
    row: 5
    col: 18
    width: 6
    height: 4
  - name: exec_p14
    type: single_value
    title: P14 - Pass Rate
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P14"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Percentage of executed test cases that passed.\nHow it's calculated: SUM(passed_count) / SUM(passed_count + failed_count + blocked_count + retest_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Daily, per sprint, per release\nTarget/threshold: Target for release builds typically >=95% depending on risk.\nOwner: POD QA Lead / Release Manager\nNotes: KPI tile plus trend line; slice by QA Group and environment."
    row: 9
    col: 0
    width: 6
    height: 4
  - name: exec_p31
    type: single_value
    title: P31 - Bug Escape Rate (by severity)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P31"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira + Bugsnag\nDefinition: Share of defects that escape to production, broken down by severity (Blocker/Critical/Major).\nHow it's calculated: (Defects found in production / (Pre-release defects + production defects)) by severity.\nGranularity: Per POD / feature / release\nTime window: Per release and weekly\nTarget/threshold: High expectation: 0–2% Blocker/Critical; <4% Majors.\nOwner: QA Director / Product Owner\nNotes: Stacked bar per severity; used as core OS expectation metric."
    row: 9
    col: 6
    width: 6
    height: 4
  - name: exec_p46
    type: single_value
    title: P46 - Defect Leak Rate (Live)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P46"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira + Bugsnag\nDefinition: Percentage of total defects that were first identified in live/production.\nHow it's calculated: Live defects / (pre-release defects + live defects) * 100\nGranularity: Per POD / release / platform\nTime window: Per release; rolling 30 days\nTarget/threshold: Target <=2%\nOwner: QA Director / LiveOps QA Lead\nNotes: Core release outcome metric; used in Go/No-Go and postmortems"
    row: 9
    col: 12
    width: 6
    height: 4
  - name: exec_p20
    type: single_value
    title: P20 - Active Production Errors
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P20"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Number of distinct Bugsnag errors that are still active (not fixed).\nHow it's calculated: COUNT DISTINCT error_id where status != 'fixed' and last_seen within monitoring window.\nGranularity: Per project / platform / release\nTime window: Daily snapshot; weekly trend\nTarget/threshold: Should trend down; specific thresholds per game.\nOwner: LiveOps QA Lead / Incident Manager\nNotes: KPI tiles per severity; main prod health snapshot."
    row: 9
    col: 18
    width: 6
    height: 4
  - name: sec_0
    type: text
    title_text: "Defects (Jira)"
    body_text: "Source: Jira. Hover a tile for definition and calculation."
    row: 13
    col: 0
    width: 24
    height: 2
  - name: p1
    type: looker_line
    title: P1 - Defects Created
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P1"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of new defect tickets created in the selected period.\nHow it's calculated: COUNT of issues where issue_type = 'Bug' and created date is in the period.\nGranularity: Per POD / feature / release / sprint\nTime window: Weekly, per sprint, per release\nTarget/threshold: No fixed target; monitor trend and unexpected spikes per POD.\nOwner: POD QA Lead\nNotes: Line chart by sprint; split by priority, component, QA Group (Dev vs External)."
    row: 15
    col: 0
    width: 12
    height: 6
  - name: p2
    type: looker_line
    title: P2 - Defects Closed
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P2"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of defect tickets resolved or closed in the selected period.\nHow it's calculated: COUNT of Bug issues with resolutiondate in the period and status in Done/Resolved/Closed.\nGranularity: Per POD / feature / release / sprint\nTime window: Weekly, per sprint, per release\nTarget/threshold: Over time, Closed >= Created to avoid backlog growth.\nOwner: POD QA Lead\nNotes: Plot together with P1 as 'Created vs Closed' trend."
    row: 15
    col: 12
    width: 12
    height: 6
  - name: p3
    type: looker_line
    title: P3 - Defects Reopened
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P3"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of defect tickets that were reopened after being resolved.\nHow it's calculated: COUNT of Bug issues that transition from resolved/closed back to an open/reopened status during the period.\nGranularity: Per POD / feature / release / sprint\nTime window: Weekly, per sprint\nTarget/threshold: As low as possible; aim for <3% of closed defects.\nOwner: POD QA Lead\nNotes: Bar chart per POD; requires Jira status history or explicit 'Reopened' status."
    row: 21
    col: 0
    width: 12
    height: 6
  - name: p4
    type: looker_line
    title: P4 - Defect Reopen Rate
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P4"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of closed defects that were subsequently reopened.\nHow it's calculated: P3 (Defects Reopened) / P2 (Defects Closed) in the same period.\nGranularity: Per POD / feature / release / sprint\nTime window: Weekly, per sprint, rolling 4 weeks\nTarget/threshold: Target <3–5%; stricter limit for Critical/High.\nOwner: QA Director / POD QA Leads\nNotes: Line chart by sprint; filter by priority and QA Group."
    row: 21
    col: 12
    width: 12
    height: 6
  - name: p5
    type: looker_line
    title: P5 - Open Defect Backlog
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P5"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Total number of unresolved defects at the end of the period.\nHow it's calculated: COUNT of Bug issues where resolutiondate IS NULL or status not in Done/Resolved/Closed at snapshot.\nGranularity: Per POD / feature / release / game\nTime window: Snapshot at end of week / sprint / release\nTarget/threshold: Backlog stable or trending down; critical backlog subject to strict limits.\nOwner: POD QA Lead\nNotes: Stacked bar by priority; use snapshot filter date."
    row: 27
    col: 0
    width: 12
    height: 6
  - name: p6
    type: looker_line
    title: P6 - Open Critical & High Defects
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P6"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Number of unresolved Critical and High priority defects.\nHow it's calculated: COUNT of Bug issues where priority in ('Blocker','Critical','High') and resolutiondate IS NULL.\nGranularity: Per POD / feature / release / game\nTime window: Snapshot at end of week / sprint / release\nTarget/threshold: Target 0 open Critical at release; High below agreed limit per feature.\nOwner: POD QA Lead / Engineering Manager\nNotes: KPI tiles per severity; used in release gates and alerts."
    row: 27
    col: 12
    width: 12
    height: 6
  - name: p7
    type: looker_line
    title: P7 - Average Age of Open Defects
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P7"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Average number of days that currently open bugs have been unresolved.\nHow it's calculated: Average DAYS between snapshot date and created for bugs where resolutiondate IS NULL.\nGranularity: Per POD / feature / priority\nTime window: Snapshot (trend weekly)\nTarget/threshold: P0/P1 should have very low average age (for example <7 days).\nOwner: POD QA Lead\nNotes: Bar chart by priority; histogram of age buckets for backlog hygiene."
    row: 33
    col: 0
    width: 12
    height: 6
  - name: p8
    type: looker_line
    title: P8 - Defect Density (Bugs per 100 Story Points)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P8"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Defects created relative to the amount of delivered work.\nHow it's calculated: Bugs created in sprint / completed story points in same sprint * 100.\nGranularity: Per POD / release / sprint\nTime window: Per sprint / release\nTarget/threshold: Benchmark per POD; track trend, not absolute value.\nOwner: QA Director / Product Owner\nNotes: Column chart per sprint; compare across PODs."
    row: 33
    col: 12
    width: 12
    height: 6
  - name: p9
    type: looker_line
    title: P9 - Time to Triage
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P9"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Average time from defect creation until it reaches the agreed triage state.\nHow it's calculated: Average HOURS between created and first timestamp where status is triage state.\nGranularity: Per POD / feature / priority\nTime window: Per sprint; rolling 4 weeks\nTarget/threshold: Target <24h for Critical/High defects.\nOwner: POD QA Lead\nNotes: Box or bar chart by priority; requires status history ingestion."
    row: 39
    col: 0
    width: 12
    height: 6
  - name: p10
    type: looker_line
    title: P10 - Time to Resolution (MTTR)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P10"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Average time from defect creation until resolution.\nHow it's calculated: Average DAYS between created and resolutiondate for bugs resolved in period.\nGranularity: Per POD / feature / priority\nTime window: Per sprint; rolling 4 and 12 weeks\nTarget/threshold: Critical issues resolved within agreed SLA (for example <3 days).\nOwner: Engineering Manager / QA Lead\nNotes: Trend line by severity; show P95 as additional series."
    row: 39
    col: 12
    width: 12
    height: 6
  - name: p11
    type: looker_line
    title: P11 - SLA Compliance for Critical/High Defects
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P11"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of Critical/High defects resolved within the agreed resolution SLA.\nHow it's calculated: Resolved Critical/High bugs within SLA window / total Critical/High resolved in period.\nGranularity: Per POD / release / sprint\nTime window: Per sprint; rolling 4 weeks\nTarget/threshold: Target >=95% for Critical, >=90% for High.\nOwner: Engineering Manager / QA Director\nNotes: Gauge or bar by POD; feed into quality gate."
    row: 45
    col: 0
    width: 12
    height: 6
  - name: p43
    type: looker_line
    title: P43 - Defect Acceptance Ratio (DAR)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P43"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of reported defects that are accepted as valid (not rejected as NAB, Duplicate, Won’t Fix).\nHow it's calculated: Accepted bugs / total bugs closed in the period * 100\nGranularity: Per POD / QA Group / feature\nTime window: Weekly, per sprint, per release\nTarget/threshold: Target >=92%\nOwner: QA Manager / POD QA Lead\nNotes: KPI tile + trend; low DAR indicates poor bug quality or requirement gaps"
    row: 45
    col: 12
    width: 12
    height: 6
  - name: p44
    type: looker_line
    title: P44 - High Severity Defect Reporting Rate (P0+P1)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P44"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of total reported defects that are P0 or P1 severity.\nHow it's calculated: (P0 + P1 bugs reported) / total bugs reported * 100\nGranularity: Per POD / QA Group / release\nTime window: Weekly, per sprint, per release\nTarget/threshold: Target >=25% Depending on The milestone phase\nOwner: POD QA Lead / QA Director\nNotes: Column chart by severity; ensures focus on meaningful defects over noise"
    row: 51
    col: 0
    width: 12
    height: 6
  - name: p45
    type: looker_line
    title: P45 - NMI Rate (No-Merge / Not Meaningful Issues)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P45"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of reported defects classified as NMI (issues that do not require a code fix or merge).\nHow it's calculated: NMI bugs / total bugs closed * 100\nGranularity: Per POD / QA Group\nTime window: Weekly, per sprint\nTarget/threshold: Target <=5%\nOwner: QA Manager\nNotes: High NMI indicates requirement clarity or test expectation issues"
    row: 51
    col: 12
    width: 12
    height: 6
  - name: sec_1
    type: text
    title_text: "Testing Execution (TestRail)"
    body_text: "Source: TestRail. Hover a tile for definition and calculation."
    row: 57
    col: 0
    width: 24
    height: 2
  - name: p12
    type: looker_line
    title: P12 - Test Runs Executed
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P12"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Number of TestRail runs executed in the selected period.\nHow it's calculated: COUNT of runs where created_on or completed_on is in the period.\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Daily, per sprint, per release\nTarget/threshold: Match planned runs for the cycle; no systematic misses.\nOwner: POD QA Lead\nNotes: Column chart per day/sprint; filter by QA Group and milestone."
    row: 59
    col: 0
    width: 12
    height: 6
  - name: p13
    type: looker_line
    title: P13 - Test Cases Executed
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P13"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Total test cases executed (passed, failed, blocked, retest).\nHow it's calculated: SUM(passed_count + failed_count + blocked_count + retest_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Daily, per sprint, per release\nTarget/threshold: Should align with planned coverage for release / test plan.\nOwner: POD QA Lead\nNotes: Line chart; stacked bar by status where useful."
    row: 59
    col: 12
    width: 12
    height: 6
  - name: p14
    type: looker_line
    title: P14 - Pass Rate
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P14"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Percentage of executed test cases that passed.\nHow it's calculated: SUM(passed_count) / SUM(passed_count + failed_count + blocked_count + retest_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Daily, per sprint, per release\nTarget/threshold: Target for release builds typically >=95% depending on risk.\nOwner: POD QA Lead / Release Manager\nNotes: KPI tile plus trend line; slice by QA Group and environment."
    row: 65
    col: 0
    width: 12
    height: 6
  - name: p15
    type: looker_line
    title: P15 - Fail Rate
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P15"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Percentage of executed test cases that failed.\nHow it's calculated: SUM(failed_count) / SUM(passed_count + failed_count + blocked_count + retest_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Daily, per sprint, per release\nTarget/threshold: Should trend down as release stabilises.\nOwner: POD QA Lead\nNotes: Stacked bar Pass/Fail/Blocked/Retest per sprint."
    row: 65
    col: 12
    width: 12
    height: 6
  - name: p16
    type: looker_line
    title: P16 - Blocked Rate
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P16"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Percentage of executed test cases that are blocked by environment, data or dependencies.\nHow it's calculated: SUM(blocked_count) / SUM(passed_count + failed_count + blocked_count + retest_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Daily, per sprint, per release\nTarget/threshold: Keep <5% where possible; spikes indicate infra issues.\nOwner: QA Env Owner / POD QA Lead\nNotes: Bar chart by environment/config; critical for capacity planning."
    row: 71
    col: 0
    width: 12
    height: 6
  - name: p17
    type: looker_line
    title: P17 - Retest Rate
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P17"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Percentage of executed test cases that required retest.\nHow it's calculated: SUM(retest_count) / SUM(passed_count + failed_count + blocked_count + retest_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Per sprint, per release\nTarget/threshold: High retest rate may indicate unstable builds or late fixes.\nOwner: POD QA Lead\nNotes: Trend line per milestone; compare across QA Groups."
    row: 71
    col: 12
    width: 12
    height: 6
  - name: p18
    type: looker_line
    title: P18 - Test Coverage (Executed vs Planned)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P18"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Coverage of planned test cases that were actually executed.\nHow it's calculated: Executed tests / (executed tests + untested_count).\nGranularity: Per POD / project / milestone / config / QA Group\nTime window: Per sprint, per release\nTarget/threshold: Typical gate >=90–95% depending on risk profile.\nOwner: POD QA Lead / Release Manager\nNotes: Gauge or bar per milestone; used in quality gate."
    row: 77
    col: 0
    width: 12
    height: 6
  - name: p19
    type: looker_line
    title: P19 - Average Test Run Duration
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P19"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail\nDefinition: Average duration of TestRail runs from creation to completion.\nHow it's calculated: Average HOURS between created_on and completed_on for completed runs.\nGranularity: Per POD / project / milestone / suite / QA Group\nTime window: Per sprint; rolling 4 weeks\nTarget/threshold: No strict target; watch for anomalies and long tails.\nOwner: POD QA Lead\nNotes: Box plot per suite/config; compare Dev vs External QA."
    row: 77
    col: 12
    width: 12
    height: 6
  - name: p26
    type: looker_line
    title: P26 - Defects per 100 Test Cases Executed
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.priority_label
    filters:
      panda_qa_kpi_facts.kpi_id: "P26"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira + TestRail\nDefinition: Ratio of defects found to test cases executed, indicating defect yield.\nHow it's calculated: (Bugs created in period / Executed test cases in period) * 100.\nGranularity: Per POD / feature / release / sprint / QA Group\nTime window: Per sprint, per release\nTarget/threshold: Used comparatively across releases and QA Groups.\nOwner: QA Director / POD QA Leads\nNotes: Column chart by sprint; separate series for Dev QA vs External QA."
    row: 83
    col: 0
    width: 12
    height: 6
  - name: sec_2
    type: text
    title_text: "Production Stability (BugSnag)"
    body_text: "Source: BugSnag. Hover a tile for definition and calculation."
    row: 89
    col: 0
    width: 24
    height: 2
  - name: p20
    type: looker_line
    title: P20 - Active Production Errors
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P20"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Number of distinct Bugsnag errors that are still active (not fixed).\nHow it's calculated: COUNT DISTINCT error_id where status != 'fixed' and last_seen within monitoring window.\nGranularity: Per project / platform / release\nTime window: Daily snapshot; weekly trend\nTarget/threshold: Should trend down; specific thresholds per game.\nOwner: LiveOps QA Lead / Incident Manager\nNotes: KPI tiles per severity; main prod health snapshot."
    row: 91
    col: 0
    width: 12
    height: 6
  - name: p21
    type: looker_line
    title: P21 - High/Critical Active Errors
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P21"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Number of active production errors with high severity.\nHow it's calculated: COUNT DISTINCT error_id where severity in ('error','critical') AND status != 'fixed'.\nGranularity: Per project / platform / release\nTime window: Daily snapshot; weekly trend\nTarget/threshold: Aim for zero open critical errors.\nOwner: LiveOps QA Lead / Eng Manager\nNotes: Dedicated tile and alerting; used in Go/No-Go for live promotions."
    row: 91
    col: 12
    width: 12
    height: 6
  - name: p22
    type: looker_line
    title: P22 - New Production Errors
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P22"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Distinct Bugsnag errors first seen in the current period.\nHow it's calculated: COUNT DISTINCT error_id where first_seen date is in the period.\nGranularity: Per project / platform / release\nTime window: Daily, per sprint, per release\nTarget/threshold: Should drop as release matures; spikes after release show regressions.\nOwner: LiveOps QA Lead\nNotes: Bar chart by release/platform; filter by severity."
    row: 97
    col: 0
    width: 12
    height: 6
  - name: p23
    type: looker_line
    title: P23 - Total Error Events (Live Incident Rate)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P23"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Total number of error events captured by Bugsnag in the period.\nHow it's calculated: SUM(events) for errors where last_seen is inside the period.\nGranularity: Per project / platform / severity\nTime window: Daily, weekly; rolling 30 days\nTarget/threshold: Trend down over time; alerts on deviations from baseline.\nOwner: LiveOps QA Lead / SRE\nNotes: Line chart with severity split; optionally normalise by DAU."
    row: 97
    col: 12
    width: 12
    height: 6
  - name: p24
    type: looker_line
    title: P24 - Users Impacted by Errors
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P24"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Total number of users affected by Bugsnag errors in the period (approximate).\nHow it's calculated: SUM(users) for errors where last_seen is in the period.\nGranularity: Per project / platform / severity\nTime window: Daily, weekly; rolling 30 days\nTarget/threshold: Minimise, especially for high severity issues.\nOwner: LiveOps QA Lead / Product Owner\nNotes: KPI tile plus trend line; used in incident reviews."
    row: 103
    col: 0
    width: 12
    height: 6
  - name: p25
    type: looker_line
    title: P25 - Average Error Lifetime
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    pivots:
      - panda_qa_kpi_facts.severity
    filters:
      panda_qa_kpi_facts.kpi_id: "P25"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag\nDefinition: Average time between first_seen and last_seen for resolved errors.\nHow it's calculated: Average DAYS between first_seen and last_seen for errors marked as fixed or inactive.\nGranularity: Per project / severity\nTime window: Rolling 30 days or per release\nTarget/threshold: Shorter lifetimes indicate faster detection & fix rollout.\nOwner: LiveOps QA Lead / Eng Manager\nNotes: Box plot by severity; correlate with Jira MTTR."
    row: 103
    col: 12
    width: 12
    height: 6
  - name: sec_3
    type: text
    title_text: "Release & Process (Manual / Mixed)"
    body_text: "Source: Manual. Hover a tile for definition and calculation."
    row: 109
    col: 0
    width: 24
    height: 2
  - name: p27
    type: single_value
    title: P27 - Production Incidents per Release
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P27"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Bugsnag (+ Jira release mapping)\nDefinition: Number of high-severity production incidents associated with a release.\nHow it's calculated: COUNT DISTINCT high/critical Bugsnag errors mapped to a release.\nGranularity: Per release / POD / platform\nTime window: Per release\nTarget/threshold: Goal: zero or minimal critical incidents per release.\nOwner: QA Director / Product Owner\nNotes: Bar chart by release; annotate big launches."
    row: 111
    col: 0
    width: 6
    height: 3
  - name: p28
    type: single_value
    title: P28 - Release Quality Gate Status
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P28"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira + TestRail + Bugsnag\nDefinition: Pass/Fail indicator summarising whether a release meets severity thresholds and coverage targets.\nHow it's calculated: Gate PASS if: coverage >= threshold; 0 open Critical; High backlog under limit; SLA compliance above target; incident rate below threshold.\nGranularity: Per release / POD\nTime window: Evaluated at each RC and before launch\nTarget/threshold: All launches should meet gate or be explicitly waived.\nOwner: QA Director / Game Leadership\nNotes: Table with PASS/FAIL per release and which criteria failed."
    row: 111
    col: 6
    width: 6
    height: 3
  - name: p29
    type: single_value
    title: P29 - Hands-on Testing Time % (Team)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P29"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Percentage of QA time spent on hands-on testing activities for each team.\nHow it's calculated: Hands-On hours / total QA hours in the period.\nGranularity: Per POD / QA Group / site\nTime window: Weekly, per sprint, per quarter\nTarget/threshold: Target 75% Hands-On at team level.\nOwner: QA Manager\nNotes: 100% stacked bar per QA Group; target reference line at 75%."
    row: 111
    col: 12
    width: 6
    height: 3
  - name: p30
    type: single_value
    title: P30 - Non Hands-on Time % (Team)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P30"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Time tracking / manual logs\nDefinition: Percentage of QA time spent on non hands-on activities (test design, meetings, training, pre-mastering).\nHow it's calculated: Non Hands-On hours / total QA hours in the period.\nGranularity: Per POD / QA Group / site\nTime window: Weekly, per sprint, per quarter\nTarget/threshold: Target around 25% Non Hands-On.\nOwner: QA Manager\nNotes: Visualised together with P29 as complement of 100%."
    row: 111
    col: 18
    width: 6
    height: 3
  - name: p35
    type: single_value
    title: P35 - Execution Result Accuracy
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P35"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail (per-case history)\nDefinition: Accuracy of test results recorded vs actual outcome (how often initial result is later changed).\nHow it's calculated: 1 - (Incorrect or changed results / total executed tests).\nGranularity: Per POD / suite / QA Group\nTime window: Per test cycle\nTarget/threshold: High expectation: very high accuracy (≈99%).\nOwner: POD QA Lead\nNotes: Requires case-level data; approximation via retest/blocked analysis if needed."
    row: 114
    col: 0
    width: 6
    height: 3
  - name: p36
    type: single_value
    title: P36 - Severity Assignment Accuracy
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P36"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira\nDefinition: Percentage of bugs whose initial severity matches the final agreed severity.\nHow it's calculated: Correct severity assignments / total bugs, where correct = no change or change within agreed tolerance.\nGranularity: Per POD / QA Group / severity\nTime window: Weekly and per release\nTarget/threshold: High expectation: close to 100%; specific tolerance per team.\nOwner: QA Manager\nNotes: Bar chart by QA Group and severity level; used for training."
    row: 114
    col: 6
    width: 6
    height: 3
  - name: p37
    type: single_value
    title: P37 - Test Execution Throughput (cases per person‑day)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P37"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: TestRail + time tracking\nDefinition: Average number of test cases executed per QA person‑day.\nHow it's calculated: Executed test cases / QA testing hours converted to person‑days.\nGranularity: Per POD / QA Group / suite\nTime window: Daily and per test cycle\nTarget/threshold: Target depends on game and complexity; watch trend rather than absolute.\nOwner: QA Manager\nNotes: Box/violin plot per POD; compare Dev QA vs Amber/GSQA."
    row: 114
    col: 12
    width: 6
    height: 3
  - name: p38
    type: single_value
    title: P38 - Bug Reporting Lead Time
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P38"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Time tracking + Jira\nDefinition: Average time between discovering an issue and logging it as a bug.\nHow it's calculated: Average minutes from detection to bug creation.\nGranularity: Per POD / QA Group\nTime window: Daily\nTarget/threshold: High expectation: very low (for example <15 minutes for most issues).\nOwner: QA Manager\nNotes: Line chart; useful to ensure rapid defect capture during sessions."
    row: 114
    col: 18
    width: 6
    height: 3
  - name: p39
    type: looker_line
    title: P39 - Fix Verification Cycle Time
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    dimensions:
      - panda_qa_kpi_facts.metric_ts_week
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P39"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Jira + TestRail / time tracking\nDefinition: Average time from a fix being ready for QA to verification completed.\nHow it's calculated: Average hours between dev-ready and QA verification completion.\nGranularity: Per POD / QA Group / severity\nTime window: Daily and per release\nTarget/threshold: Targets per severity (e.g., same‑day for Critical).\nOwner: POD QA Lead\nNotes: Bar chart by severity; feed into SLA discussions with dev."
    row: 135
    col: 0
    width: 12
    height: 6
  - name: p40
    type: single_value
    title: P40 - Exploratory Session Reporting Coverage
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P40"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Time tracking / exploratory session logs\nDefinition: Coverage and time spent in documented exploratory testing sessions.\nHow it's calculated: Documented exploratory sessions / total exploratory sessions; plus total hours.\nGranularity: Per POD / QA Group / area\nTime window: Weekly\nTarget/threshold: High expectation: near 100% of exploratory sessions documented.\nOwner: QA Manager\nNotes: Bar chart of coverage % plus hours as second axis."
    row: 117
    col: 6
    width: 6
    height: 3
  - name: p41
    type: single_value
    title: P41 - Time to Flag
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value
    filters:
      panda_qa_kpi_facts.kpi_id: "P41"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Time tracking / comms tools (Slack, etc.)\nDefinition: Time to escalate and communicate critical risks/blockers from detection to correct channel.\nHow it's calculated: Average minutes from risk detection to first flag.\nGranularity: Per POD / QA Group\nTime window: Daily\nTarget/threshold: Expectation: very quick (for example within same test session).\nOwner: QA Manager / Production\nNotes: Used in incident postmortems; can be approximated manually at first."
    row: 117
    col: 12
    width: 6
    height: 3
  - name: p42
    type: single_value
    title: P42 - Response Time SLA (Comms interaction)
    model: panda_qa_metrics
    explore: panda_qa_kpi_facts
    measures:
      - panda_qa_kpi_facts.kpi_value_percent
    filters:
      panda_qa_kpi_facts.kpi_id: "P42"
      panda_qa_kpi_facts.privacy_level: "public"
    listen:
      date_range: panda_qa_kpi_facts.metric_ts_time
      pod: panda_qa_kpi_facts.pod
      feature: panda_qa_kpi_facts.feature
      release: panda_qa_kpi_facts.release
      sprint: panda_qa_kpi_facts.sprint
      severity: panda_qa_kpi_facts.severity
      priority: panda_qa_kpi_facts.priority_label
    note_display: hover
    note_text: "Source: Comms tools + time tracking\nDefinition: Time QA takes to acknowledge and respond to urgent vs general requests in communication channels.\nHow it's calculated: Average response time in minutes, tracked separately for urgent vs general.\nGranularity: Per POD / QA Group\nTime window: Weekly\nTarget/threshold: High expectation: <10 min for urgent, <30 min for general requests.\nOwner: QA Manager\nNotes: Bar or box plot; tie into collaboration OS expectations."
    row: 117
    col: 18
    width: 6
    height: 3
