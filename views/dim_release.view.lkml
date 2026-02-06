# Release dimension
# Generated: 2026-01-08T12:27:33.921902Z

view: dim_release {
  sql_table_name: `qa-panda-metrics.qa_metrics.dim_release` ;;

  dimension: release_key { primary_key: yes type: string sql: ${TABLE}.release_key ;; }
  dimension: release_name { type: string sql: ${TABLE}.release_name ;; }
  dimension: game_version { type: string sql: ${TABLE}.game_version ;; }
  dimension_group: release_window {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.release_start_ts ;;
  }
  dimension: release_start_ts { type: time sql: ${TABLE}.release_start_ts ;; }
  dimension: release_end_ts { type: time sql: ${TABLE}.release_end_ts ;; }
  dimension: jira_fix_version { type: string sql: ${TABLE}.jira_fix_version ;; }
  dimension: is_public { type: yesno sql: ${TABLE}.is_public ;; }
}
