# Jira issues (latest)
# Generated: 2026-01-08T12:27:33.921958Z

view: jira_issues {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_jira_issues_latest` ;;

  dimension: issue_id { primary_key: yes type: number sql: ${TABLE}.issue_id ;; }
  dimension: issue_key { type: string sql: ${TABLE}.issue_key ;; }
  dimension: issue_url { type: string sql: ${TABLE}.issue_url ;; }

  dimension: issue_type { type: string sql: ${TABLE}.issue_type ;; }
  dimension: summary { type: string sql: ${TABLE}.summary ;; }

  dimension: status { type: string sql: ${TABLE}.status ;; }
  dimension: priority { type: string sql: ${TABLE}.priority ;; }
  dimension: severity { type: string sql: ${TABLE}.severity ;; }

  dimension: project_key { type: string sql: ${TABLE}.project_key ;; }

  dimension: assignee_account_id { type: string sql: ${TABLE}.assignee_account_id ;; }
  dimension: reporter_account_id { type: string sql: ${TABLE}.reporter_account_id ;; }

  dimension: fix_version { type: string sql: ${TABLE}.fix_version ;; }

  dimension: story_points { type: number sql: ${TABLE}.story_points ;; }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.created_at ;;
  }

  dimension_group: updated {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.updated_at ;;
  }

  dimension_group: resolved {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.resolved_at ;;
  }

  measure: issues { type: count }
  measure: open_issues { type: count filters: [status: "-Done,-Closed,-Resolved"] }
}
