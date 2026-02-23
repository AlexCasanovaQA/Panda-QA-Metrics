view: jira_active_bug_count_daily {
  sql_table_name: `qa_metrics.jira_active_bug_count_daily` ;;

  dimension_group: metric_date {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.metric_date ;;
  }

  measure: active_bug_count {
    type: max
    sql: ${TABLE}.active_bug_count ;;
    value_format_name: decimal_0
  }
}
