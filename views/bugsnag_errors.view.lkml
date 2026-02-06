# Bugsnag errors (latest)
# Generated: 2026-01-08T12:27:33.922091Z

view: bugsnag_errors {
  sql_table_name: `qa-panda-metrics.qa_metrics.bugsnag_errors_latest` ;;

  dimension: error_id { primary_key: yes type: string sql: ${TABLE}.error_id ;; }
  dimension: project_id { type: number sql: ${TABLE}.project_id ;; }
  dimension: severity { type: string sql: ${TABLE}.severity ;; }
  dimension: status { type: string sql: ${TABLE}.status ;; }

  dimension_group: first_seen {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.first_seen ;;
  }

  dimension_group: last_seen {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.last_seen ;;
  }

  measure: errors { type: count }
  measure: open_errors { type: count filters: [status: "open"] }
}
