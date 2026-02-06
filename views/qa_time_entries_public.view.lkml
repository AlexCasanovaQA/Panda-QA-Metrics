# Manual time entries (public-safe)
# Generated: 2026-01-08T12:27:33.922393Z

view: qa_time_entries_public {
  sql_table_name: `qa-panda-metrics.qa_metrics.qa_time_entries_public` ;;

  dimension_group: entry_date {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.entry_date ;;
  }

  dimension: pod { type: string sql: ${TABLE}.pod ;; }
  dimension: activity { type: string sql: ${TABLE}.activity ;; }
  dimension: is_hands_on { type: yesno sql: ${TABLE}.is_hands_on ;; }

  measure: hours { type: sum sql: ${TABLE}.hours ;; value_format_name: "decimal_2" }
}
