dashboard: qa_kpis_public {
  title: "QA KPIs - Public"
  layout: newspaper
  preferred_viewer: dashboards-next
  refresh: 1 hour

  filter: date_range {
    title: "Date Range"
    type: date_filter
    default_value: "90 days"
  }

  filter: pod {
    title: "POD"
    type: field_filter
    field: qa_kpi_facts.pod
  }
  filter: feature {
    title: "Feature"
    type: field_filter
    field: qa_kpi_facts.feature
  }
  filter: release {
    title: "Release"
    type: field_filter
    field: qa_kpi_facts.release
  }
  filter: sprint {
    title: "Sprint"
    type: field_filter
    field: qa_kpi_facts.sprint
  }
  filter: severity {
    title: "Severity"
    type: field_filter
    field: qa_kpi_facts.severity
  }

  element: intro_text {
    type: text
    title_text: "How to use"
    body_text: "Use the filters above to slice KPIs by POD/Feature/Release/Sprint. Public users only see public KPIs. Leads can access private KPIs in the private dashboard."
    row: 0
    col: 0
    width: 24
    height: 3
  }

  element: kpi_p1 {
    title: "P1 - Defects Created"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P1"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 3
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p2 {
    title: "P2 - Defects Closed"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P2"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 3
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p3 {
    title: "P3 - Defects Reopened"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P3"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 3
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p4 {
    title: "P4 - Defect Reopen Rate"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P4"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 3
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p5 {
    title: "P5 - Open Defect Backlog"
    type: single_value
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P5"
      qa_kpi_facts.privacy_level: "public"
    }
    limit: 500
    listen: {
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 8
    col: 0
    width: 6
    height: 3
  }

  element: kpi_p6 {
    title: "P6 - Open Critical & High Defects"
    type: single_value
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P6"
      qa_kpi_facts.privacy_level: "public"
    }
    limit: 500
    listen: {
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 8
    col: 6
    width: 6
    height: 3
  }

  element: kpi_p7 {
    title: "P7 - Average Age of Open Defects"
    type: single_value
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P7"
      qa_kpi_facts.privacy_level: "public"
    }
    limit: 500
    listen: {
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 8
    col: 12
    width: 6
    height: 3
  }

  element: kpi_p8 {
    title: "P8 - Defect Density (Bugs per 100 Story Points)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P8"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 38
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p9 {
    title: "P9 - Time to Triage"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P9"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 8
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p10 {
    title: "P10 - Time to Resolution (MTTR)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P10"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 13
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p11 {
    title: "P11 - SLA Compliance for Critical/High Defects"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P11"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 13
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p12 {
    title: "P12 - Test Runs Executed"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P12"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 23
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p13 {
    title: "P13 - Test Cases Executed"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P13"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 23
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p14 {
    title: "P14 - Pass Rate"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P14"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 23
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p15 {
    title: "P15 - Fail Rate"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P15"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 23
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p16 {
    title: "P16 - Blocked Rate"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P16"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 28
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p17 {
    title: "P17 - Retest Rate"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P17"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 28
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p18 {
    title: "P18 - Test Coverage (Executed vs Planned)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P18"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 28
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p19 {
    title: "P19 - Average Test Run Duration"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P19"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 28
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p20 {
    title: "P20 - Active Production Errors"
    type: single_value
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P20"
      qa_kpi_facts.privacy_level: "public"
    }
    limit: 500
    listen: {
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 33
    col: 0
    width: 6
    height: 3
  }

  element: kpi_p21 {
    title: "P21 - High/Critical Active Errors"
    type: single_value
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P21"
      qa_kpi_facts.privacy_level: "public"
    }
    limit: 500
    listen: {
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 33
    col: 6
    width: 6
    height: 3
  }

  element: kpi_p22 {
    title: "P22 - New Production Errors"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P22"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 33
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p23 {
    title: "P23 - Total Error Events (Live Incident Rate)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P23"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 33
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p24 {
    title: "P24 - Users Impacted by Errors"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P24"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 38
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p25 {
    title: "P25 - Average Error Lifetime"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P25"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 38
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p26 {
    title: "P26 - Defects per 100 Test Cases Executed"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P26"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 38
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p27 {
    title: "P27 - Production Incidents per Release"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P27"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p28 {
    title: "P28 - Release Quality Gate Status"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P28"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p29 {
    title: "P29 - Hands-on Testing Time % (Team)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P29"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p30 {
    title: "P30 - Non Hands-on Time % (Team)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P30"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p31 {
    title: "P31 - Bug Escape Rate (by severity)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P31"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 43
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p32 {
    title: "P32 - Defect Detection Efficiency (DDE)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P32"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 43
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p33 {
    title: "P33 - Bug Rejection Rate"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P33"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 13
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p34 {
    title: "P34 - Bug Report Completeness"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P34"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 13
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p35 {
    title: "P35 - Execution Result Accuracy"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P35"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p36 {
    title: "P36 - Severity Assignment Accuracy"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P36"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p37 {
    title: "P37 - Test Execution Throughput (cases per person‑day)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P37"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p38 {
    title: "P38 - Bug Reporting Lead Time"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P38"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p39 {
    title: "P39 - Fix Verification Cycle Time"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P39"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 18
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p40 {
    title: "P40 - Exploratory Session Reporting Coverage"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P40"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p41 {
    title: "P41 - Time to Flag"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P41"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p42 {
    title: "P42 - Response Time SLA (Comms interaction)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "P42"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 4
  }

  element: kpi_p43 {
    title: "P43 - Defect Acceptance Ratio (DAR)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P43"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 18
    col: 6
    width: 6
    height: 4
  }

  element: kpi_p44 {
    title: "P44 - High Severity Defect Reporting Rate (P0+P1)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P44"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 18
    col: 12
    width: 6
    height: 4
  }

  element: kpi_p45 {
    title: "P45 - NMI Rate (No-Merge / Not Meaningful Issues)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P45"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 18
    col: 18
    width: 6
    height: 4
  }

  element: kpi_p46 {
    title: "P46 - Defect Leak Rate (Live)"
    type: looker_line
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.metric_date_week, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "P46"
      qa_kpi_facts.privacy_level: "public"
    }
    sorts: [qa_kpi_facts.metric_date_week]
    limit: 500
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
    }
    row: 43
    col: 12
    width: 6
    height: 4
  }

}