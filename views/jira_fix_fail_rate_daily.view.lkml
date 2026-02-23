view: jira_fix_fail_rate_daily {
  sql_table_name: `qa_metrics.jira_fix_fail_rate_daily` ;;

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.event_date ;;
  }

  dimension: fixed_count { type: number sql: ${TABLE}.fixed_count ;; }
  dimension: reopened_count { type: number sql: ${TABLE}.reopened_count ;; }

  measure: fixed {
    type: sum
    sql: ${fixed_count} ;;
    value_format_name: decimal_0
  }

  measure: reopened {
    type: sum
    sql: ${reopened_count} ;;
    value_format_name: decimal_0
  }

  measure: fix_fail_rate {
    type: number
    sql: SAFE_DIVIDE(SUM(${reopened_count}), NULLIF(SUM(${fixed_count}),0)) ;;
    value_format_name: percent_2
  }
}
