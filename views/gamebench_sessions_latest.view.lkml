view: gamebench_sessions_latest {
  sql_table_name: `qa_metrics.gamebench_sessions_latest` ;;

  dimension: session_id { type: string primary_key: yes sql: ${TABLE}.session_id ;; }
  dimension_group: time_pushed {
    type: time
    timeframes: [raw, time, date, week, month]
    sql: ${TABLE}.time_pushed ;;
  }

  dimension: environment { type: string sql: ${TABLE}.environment ;; }
  dimension: platform    { type: string sql: ${TABLE}.platform ;; }
  dimension: app_package { type: string sql: ${TABLE}.app_package ;; }
  dimension: app_version { type: string sql: ${TABLE}.app_version ;; }

  dimension: device_model        { type: string sql: ${TABLE}.device_model ;; }
  dimension: device_manufacturer { type: string sql: ${TABLE}.device_manufacturer ;; }
  dimension: os_version          { type: string sql: ${TABLE}.os_version ;; }
  dimension: gpu_model           { type: string sql: ${TABLE}.gpu_model ;; }

  measure: sessions { type: count }

  measure: median_fps { type: average sql: ${TABLE}.median_fps ;; value_format_name: decimal_2 }
  measure: fps_stability_pct { type: average sql: ${TABLE}.fps_stability_pct ;; value_format_name: percent_2 }
  measure: fps_stability_index { type: average sql: ${TABLE}.fps_stability_index ;; value_format_name: decimal_2 }
}
