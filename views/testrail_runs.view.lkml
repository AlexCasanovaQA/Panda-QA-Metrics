# TestRail runs (latest)
# Generated: 2026-01-08T12:27:33.922147Z

view: testrail_runs {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_testrail_runs_latest` ;;

  dimension: run_id { primary_key: yes type: number sql: ${TABLE}.run_id ;; }
  dimension: project_id { type: number sql: ${TABLE}.project_id ;; }
  dimension: suite_id { type: number sql: ${TABLE}.suite_id ;; }

  dimension: name { type: string sql: ${TABLE}.name ;; }
  dimension: url { type: string sql: ${TABLE}.url ;; }

  dimension: is_completed { type: yesno sql: ${TABLE}.is_completed ;; }

  dimension: created_by_id { type: number sql: ${TABLE}.created_by_id ;; }
  dimension: assignedto_id { type: number sql: ${TABLE}.assignedto_id ;; }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.created_on ;;
  }

  dimension_group: updated {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.updated_on ;;
  }

  measure: runs { type: count }
  measure: passed_total { type: sum sql: ${TABLE}.passed_count ;; }
  measure: failed_total { type: sum sql: ${TABLE}.failed_count ;; }
  measure: blocked_total { type: sum sql: ${TABLE}.blocked_count ;; }
  measure: untested_total { type: sum sql: ${TABLE}.untested_count ;; }
}
