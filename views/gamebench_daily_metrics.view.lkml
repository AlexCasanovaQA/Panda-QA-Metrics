view: gamebench_daily_metrics {
  sql_table_name: `qa_metrics.gamebench_daily_metrics` ;;

  dimension_group: metric_date {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.metric_date ;;
  }

  dimension: environment { type: string sql: ${TABLE}.environment ;; }
  dimension: platform { type: string sql: ${TABLE}.platform ;; }
  dimension: app_package { type: string sql: ${TABLE}.app_package ;; }
  dimension: app_version { type: string sql: ${TABLE}.app_version ;; }
  dimension: device_model { type: string sql: ${TABLE}.device_model ;; }
  dimension: device_manufacturer { type: string sql: ${TABLE}.device_manufacturer ;; }
  dimension: os_version { type: string sql: ${TABLE}.os_version ;; }
  dimension: gpu_model { type: string sql: ${TABLE}.gpu_model ;; }

  measure: sessions { type: sum sql: ${TABLE}.sessions ;; value_format_name: decimal_0 }

  measure: median_fps { type: average sql: ${TABLE}.median_fps ;; value_format_name: decimal_2 }
  measure: fps_stability_pct { type: average sql: ${TABLE}.fps_stability_pct ;; value_format_name: percent_2 }
  measure: fps_stability_index { type: average sql: ${TABLE}.fps_stability_index ;; value_format_name: decimal_2 }

  measure: cpu_avg_pct { type: average sql: ${TABLE}.cpu_avg_pct ;; value_format_name: percent_2 }
  measure: cpu_max_pct { type: max sql: ${TABLE}.cpu_max_pct ;; value_format_name: percent_2 }

  measure: memory_avg_mb { type: average sql: ${TABLE}.memory_avg_mb ;; value_format_name: decimal_2 }
  measure: memory_max_mb { type: max sql: ${TABLE}.memory_max_mb ;; value_format_name: decimal_2 }

  measure: current_avg_ma { type: average sql: ${TABLE}.current_avg_ma ;; value_format_name: decimal_2 }
}
