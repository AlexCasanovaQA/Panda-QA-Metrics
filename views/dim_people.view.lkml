# People dimension
# Generated: 2026-01-08T12:27:33.921838Z

view: dim_people {
  sql_table_name: `qa-panda-metrics.qa_metrics.dim_people` ;;

  dimension: person_key { primary_key: yes type: string sql: ${TABLE}.person_key ;; }

  dimension: name { type: string sql: ${TABLE}.name ;; }
  dimension: email { type: string sql: ${TABLE}.email ;; }

  dimension: role { type: string sql: ${TABLE}.role ;; }
  dimension: qa_group { type: string sql: ${TABLE}.qa_group ;; }
  dimension: pod { type: string sql: ${TABLE}.pod ;; }

  dimension: jira_account_id { type: string sql: ${TABLE}.jira_account_id ;; }
  dimension: jira_display_name { type: string sql: ${TABLE}.jira_display_name ;; }

  dimension: testrail_user_id { type: number sql: ${TABLE}.testrail_user_id ;; }
  dimension: is_active { type: yesno sql: ${TABLE}.is_active ;; }

  dimension_group: updated {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.updated_at ;;
  }
}
