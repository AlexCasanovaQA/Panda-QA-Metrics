# Manual time entries (private)
# Generated: 2026-01-08T12:27:33.922341Z

view: qa_time_entries {
  sql_table_name: `qa-panda-metrics.qa_metrics.qa_time_entries` ;;

  dimension: entry_id { primary_key: yes type: string sql: ${TABLE}.entry_id ;; }

  dimension_group: entry_date {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.entry_date ;;
  }

  dimension: person_key { type: string sql: ${TABLE}.person_key ;; }
  dimension: pod { type: string sql: ${TABLE}.pod ;; }
  dimension: activity { type: string sql: ${TABLE}.activity ;; }
  dimension: is_hands_on { type: yesno sql: ${TABLE}.is_hands_on ;; }

  measure: hours { type: sum sql: ${TABLE}.hours ;; value_format_name: "decimal_2" }
}
