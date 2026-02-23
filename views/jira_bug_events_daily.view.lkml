view: jira_bug_events_daily {
  sql_table_name: `qa_metrics.jira_bug_events_daily` ;;

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.event_date ;;
  }

  dimension: event_type { type: string sql: ${TABLE}.event_type ;; }
  dimension: priority_label { type: string sql: ${TABLE}.priority_label ;; }
  dimension: severity_label { type: string sql: ${TABLE}.severity_label ;; }
  dimension: pod { label: "POD" type: string sql: ${TABLE}.pod ;; }

  measure: bugs {
    type: sum
    sql: ${TABLE}.bugs_count ;;
    value_format_name: decimal_0
  }
}
