view: build_size_manual {
  sql_table_name: `qa_metrics.build_size_manual` ;;

  dimension_group: metric_date {
    type: time
    timeframes: [date, week, month]
    # Source column is DATE; cast to TIMESTAMP so dashboard date_filter boundaries
    # (rendered as TIMESTAMP in BigQuery) compare with matching types.
    sql: TIMESTAMP(${TABLE}.metric_date) ;;
  }

  dimension: platform { type: string sql: ${TABLE}.platform ;; }
  dimension: environment { type: string sql: ${TABLE}.environment ;; }
  dimension: build_version { type: string sql: ${TABLE}.build_version ;; }

  measure: build_size_mb { type: max sql: ${TABLE}.build_size_mb ;; value_format_name: decimal_2 }
}
