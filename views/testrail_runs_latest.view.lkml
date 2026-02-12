view: testrail_runs_latest {
  sql_table_name: `qa_metrics.testrail_runs_latest` ;;

  dimension: run_id { type: number primary_key: yes sql: ${TABLE}.run_id ;; }
  dimension: project_id { type: number sql: ${TABLE}.project_id ;; }
  dimension: name { type: string sql: ${TABLE}.name ;; }
  dimension: is_completed { type: yesno sql: ${TABLE}.is_completed ;; }

  dimension_group: created_on {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created_on ;;
  }

  dimension_group: completed_on {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.completed_on ;;
  }

  dimension: passed_count { type: number sql: ${TABLE}.passed_count ;; }
  dimension: failed_count { type: number sql: ${TABLE}.failed_count ;; }
  dimension: blocked_count { type: number sql: ${TABLE}.blocked_count ;; }
  dimension: retest_count { type: number sql: ${TABLE}.retest_count ;; }
  dimension: untested_count { type: number sql: ${TABLE}.untested_count ;; }

  measure: runs { type: count }
}
