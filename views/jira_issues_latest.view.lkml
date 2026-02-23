view: jira_issues_latest {
  sql_table_name: `qa_metrics.jira_issues_latest` ;;

  dimension: issue_key { type: string primary_key: yes sql: ${TABLE}.issue_key ;; }
  dimension: id { type: string sql: ${TABLE}.id ;; }
  dimension: project_key { type: string sql: ${TABLE}.project_key ;; }
  dimension: summary { type: string sql: ${TABLE}.summary ;; }
  dimension: description_plain { type: string sql: ${TABLE}.description_plain ;; }

  dimension: issue_type { type: string sql: ${TABLE}.issue_type ;; }
  dimension: status { type: string sql: ${TABLE}.status ;; }
  dimension: status_category { type: string sql: ${TABLE}.status_category ;; }
  dimension: priority { type: string sql: ${TABLE}.priority ;; }
  dimension: severity { type: string sql: ${TABLE}.severity ;; }

  dimension: assignee { type: string sql: ${TABLE}.assignee ;; }
  dimension: reporter { type: string sql: ${TABLE}.reporter ;; }

  dimension: team { label: "POD" type: string sql: ${TABLE}.team ;; }
  dimension: sprint { type: string sql: ${TABLE}.sprint ;; }
  dimension: fix_versions { type: string sql: ${TABLE}.fix_versions ;; }
  dimension: components { type: string sql: ${TABLE}.components ;; }
  dimension: labels { type: string sql: ${TABLE}.labels ;; }

  dimension: story_points { type: number sql: ${TABLE}.story_points ;; }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created ;;
  }

  dimension_group: updated {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.updated ;;
  }

  dimension_group: resolutiondate {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.resolutiondate ;;
  }

  dimension: resolution { type: string sql: ${TABLE}.resolution ;; }

  measure: issues { type: count }
}
