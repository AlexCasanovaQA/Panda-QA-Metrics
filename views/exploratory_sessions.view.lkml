view: exploratory_sessions {
  sql_table_name: `qa-panda-metrics.qa_metrics.exploratory_sessions` ;;

  primary_key: session_id

  dimension: session_id {
    type: string
    sql: ${TABLE}.session_id ;;
  }

  dimension_group: session {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.session_date ;;
  }

  dimension: person_key {
    type: string
    sql: ${TABLE}.person_key ;;
  }

  dimension: pod {
    type: string
    sql: ${TABLE}.pod ;;
  }

  dimension: notes_link {
    type: string
    sql: ${TABLE}.notes_link ;;
  }

  dimension: has_notes {
    type: yesno
    sql: ${TABLE}.notes_link IS NOT NULL AND ${TABLE}.notes_link != '' ;;
  }

  dimension: flagged_to_leads {
    type: yesno
    sql: COALESCE(${TABLE}.flagged_to_leads, FALSE) ;;
  }

  dimension: issues_found {
    type: number
    sql: ${TABLE}.issues_found ;;
  }

  dimension: hours {
    type: number
    sql: ${TABLE}.hours ;;
    value_format_name: decimal_1
  }

  measure: sessions {
    type: count
  }

  measure: total_hours {
    type: sum
    sql: ${hours} ;;
    value_format_name: decimal_1
  }

  measure: sessions_with_notes {
    type: count
    filters: [has_notes: "yes"]
  }

  measure: reporting_coverage {
    label: "Reporting Coverage"
    type: number
    sql: SAFE_DIVIDE(${sessions_with_notes}, ${sessions}) ;;
    value_format_name: percent_1
  }

  # KPI helpers
  measure: kpi_p40_reporting_coverage {
    label: "KPI P40 - Exploratory Session Reporting Coverage"
    type: number
    sql: SAFE_DIVIDE(${sessions_with_notes}, ${sessions}) ;;
    value_format_name: percent_1
  }
}
