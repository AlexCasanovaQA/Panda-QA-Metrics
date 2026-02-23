view: jira_mttr_claimed_fixed_daily {
  sql_table_name: `qa_metrics.jira_mttr_claimed_fixed_daily` ;;

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: TIMESTAMP(${TABLE}.event_date) ;;
  }

  measure: avg_mttr_hours {
    type: average
    sql: ${TABLE}.avg_mttr_hours ;;
    value_format_name: decimal_2
  }

  measure: issues_count {
    type: sum
    sql: ${TABLE}.issues_count ;;
  }
}
