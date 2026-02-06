# TestRail results (latest)
# Generated: 2026-01-08T12:27:33.922213Z

view: testrail_results {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_testrail_results_latest` ;;

  dimension: result_id { primary_key: yes type: number sql: ${TABLE}.result_id ;; }
  dimension: run_id { type: number sql: ${TABLE}.run_id ;; }
  dimension: test_id { type: number sql: ${TABLE}.test_id ;; }
  dimension: case_id { type: number sql: ${TABLE}.case_id ;; }

  dimension: status_id { type: number sql: ${TABLE}.status_id ;; }
  dimension: status { type: string sql: ${TABLE}.status ;; }

  dimension: created_by_id { type: number sql: ${TABLE}.created_by_id ;; }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.created_on ;;
  }

  measure: results { type: count }
  measure: passed { type: count filters: [status: "passed"] }
  measure: failed { type: count filters: [status: "failed"] }
  measure: blocked { type: count filters: [status: "blocked"] }
  measure: retest { type: count filters: [status: "retest"] }
  measure: untested { type: count filters: [status: "untested"] }
}
