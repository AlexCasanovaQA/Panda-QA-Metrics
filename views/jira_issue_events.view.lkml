# Jira issue events (changelog items)
# Generated: 2026-01-08T12:27:33.922033Z

view: jira_issue_events {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_jira_issue_events_latest` ;;

  dimension: event_key { primary_key: yes type: string sql: ${TABLE}.event_key ;; }

  dimension: issue_id { type: number sql: ${TABLE}.issue_id ;; }
  dimension: issue_key { type: string sql: ${TABLE}.issue_key ;; }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.created_at ;;
  }

  dimension: field { type: string sql: ${TABLE}.field ;; }
  dimension: from_string { type: string sql: ${TABLE}.from_string ;; }
  dimension: to_string { type: string sql: ${TABLE}.to_string ;; }

  dimension: author_account_id { type: string sql: ${TABLE}.author_account_id ;; }
  dimension: author_display_name { type: string sql: ${TABLE}.author_display_name ;; }

  measure: events { type: count }
}
