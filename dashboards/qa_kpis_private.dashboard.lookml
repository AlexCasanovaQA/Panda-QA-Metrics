dashboard: qa_kpis_private {
  title: "QA KPIs - Private (Leads)"
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

  filter: qa_user {
    title: "QA User"
    type: field_filter
    field: qa_kpi_facts.qa_user
  }
  filter: developer_user {
    title: "Developer"
    type: field_filter
    field: qa_kpi_facts.developer_user
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

  element: kpi_r1 {
    title: "R1 - Hands-on Testing Time % per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R1"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r2 {
    title: "R2 - Non Hands-on Time % per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R2"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r3 {
    title: "R3 - Hands-on Hours by Activity per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R3"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r4 {
    title: "R4 - Non Hands-on Hours by Activity per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R4"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r5 {
    title: "R5 - Deviation from 75/25 Hands-on Mix per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R5"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r6 {
    title: "R6 - Test Cases Executed per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R6"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 3
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r7 {
    title: "R7 - Pass Rate per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "R7"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value_percent desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 3
    col: 6
    width: 6
    height: 5
  }

  element: kpi_r8 {
    title: "R8 - Fail Rate per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "R8"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value_percent desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 3
    col: 12
    width: 6
    height: 5
  }

  element: kpi_r9 {
    title: "R9 - Average Test Run Duration per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R9"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 3
    col: 18
    width: 6
    height: 5
  }

  element: kpi_r10 {
    title: "R10 - Test Cases per Hour per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R10"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r11 {
    title: "R11 - Defects Reported per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R11"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 8
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r12 {
    title: "R12 - High/Critical Defects Reported per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R12"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 8
    col: 6
    width: 6
    height: 5
  }

  element: kpi_r13 {
    title: "R13 - Defect Yield per QA (Defects per 100 Executed Tests)"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R13"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 8
    col: 12
    width: 6
    height: 5
  }

  element: kpi_r14 {
    title: "R14 - Reopen Rate for Defects Reported by QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "R14"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value_percent desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 8
    col: 18
    width: 6
    height: 5
  }

  element: kpi_r15 {
    title: "R15 - Bug Report Completeness per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "R15"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value_percent desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 13
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r16 {
    title: "R16 - Bug Rejection Rate per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.qa_user, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "R16"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value_percent desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 13
    col: 6
    width: 6
    height: 5
  }

  element: kpi_r17 {
    title: "R17 - Severity Assignment Accuracy per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R17"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r18 {
    title: "R18 - Bug Reporting Lead Time per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R18"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r19 {
    title: "R19 - Time to Flag per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R19"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r20 {
    title: "R20 - Response Time SLA per QA"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R20"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r21 {
    title: "R21 - Bugs Assigned per Developer"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R21"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 13
    col: 12
    width: 6
    height: 5
  }

  element: kpi_r22 {
    title: "R22 - Average Time to Resolution per Developer"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R22"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 13
    col: 18
    width: 6
    height: 5
  }

  element: kpi_r23 {
    title: "R23 - Reopen Rate per Developer"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value_percent]
    filters: {
      qa_kpi_facts.kpi_id: "R23"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value_percent desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    row: 18
    col: 0
    width: 6
    height: 5
  }

  element: kpi_r24 {
    title: "R24 - QA Capacity vs Expectation per POD"
    type: looker_bar
    model: qa_metrics
    explore: qa_kpi_facts
    fields: [qa_kpi_facts.developer_user, qa_kpi_facts.kpi_value]
    filters: {
      qa_kpi_facts.kpi_id: "R24"
      qa_kpi_facts.privacy_level: "private"
    }
    sorts: [qa_kpi_facts.kpi_value desc]
    limit: 50
    listen: {
      date_range: qa_kpi_facts.metric_date_date
      pod: qa_kpi_facts.pod
      feature: qa_kpi_facts.feature
      release: qa_kpi_facts.release
      sprint: qa_kpi_facts.sprint
      severity: qa_kpi_facts.severity
      qa_user: qa_kpi_facts.qa_user
      developer_user: qa_kpi_facts.developer_user
    }
    hidden: yes
    row: 999
    col: 0
    width: 6
    height: 5
  }

}