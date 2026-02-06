# TestRail per-test history (first vs last status)
# Generated: 2026-01-08T12:27:33.922275Z

view: testrail_test_result_history {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_testrail_test_result_history` ;;

  dimension: test_id { primary_key: yes type: number sql: ${TABLE}.test_id ;; }
  dimension: run_id { type: number sql: ${TABLE}.run_id ;; }
  dimension: case_id { type: number sql: ${TABLE}.case_id ;; }

  dimension: first_status { type: string sql: ${TABLE}.first_status ;; }
  dimension: last_status { type: string sql: ${TABLE}.last_status ;; }

  dimension: changed_result { type: yesno sql: ${TABLE}.changed_result ;; }

  dimension: first_created_by_id { type: number sql: ${TABLE}.first_created_by_id ;; }
  dimension: last_created_by_id { type: number sql: ${TABLE}.last_created_by_id ;; }

  dimension_group: first_created {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.first_created_on ;;
  }

  dimension_group: last_created {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.last_created_on ;;
  }

  measure: tests { type: count }
  measure: changed_tests { type: count filters: [changed_result: "yes"] }
  measure: execution_result_accuracy {
    type: number
    sql: SAFE_DIVIDE(${tests} - ${changed_tests}, NULLIF(${tests}, 0)) ;;
    value_format_name: "percent_2"
  }
}
