view: jira_issue_status_times {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_jira_issue_status_times` ;;

  primary_key: issue_id

  dimension: issue_id {
    type: number
    sql: ${TABLE}.issue_id ;;
  }

  dimension: issue_key {
    type: string
    sql: ${TABLE}.issue_key ;;
  }

  dimension_group: created_at {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.created_at ;;
  }

  dimension_group: triage_entered_at {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.triage_entered_at ;;
  }

  dimension_group: resolved_at {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.resolved_at ;;
  }

  dimension_group: ready_for_qa_at {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.ready_for_qa_at ;;
  }

  dimension_group: verified_at {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.verified_at ;;
  }

  dimension: triage_minutes {
    type: number
    value_format_name: decimal_0
    sql: ${TABLE}.triage_minutes ;;
  }

  dimension: resolution_minutes {
    type: number
    value_format_name: decimal_0
    sql: ${TABLE}.resolution_minutes ;;
  }

  dimension: verify_cycle_minutes {
    type: number
    value_format_name: decimal_0
    sql: ${TABLE}.verify_cycle_minutes ;;
  }

  dimension: reopen_count {
    type: number
    sql: ${TABLE}.reopen_count ;;
  }

  measure: issues {
    type: count
  }

  measure: reopened_issues {
    type: count_distinct
    sql: CASE WHEN ${reopen_count} > 0 THEN ${issue_id} ELSE NULL END ;;
    drill_fields: [issue_key]
  }

  measure: average_triage_hours {
    type: average
    value_format_name: decimal_2
    sql: ${triage_minutes} / 60.0 ;;
  }

  measure: average_resolution_hours {
    type: average
    value_format_name: decimal_2
    sql: ${resolution_minutes} / 60.0 ;;
  }

  measure: average_verify_cycle_hours {
    type: average
    value_format_name: decimal_2
    sql: ${verify_cycle_minutes} / 60.0 ;;
  }
}
