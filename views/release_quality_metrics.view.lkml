view: release_quality_metrics {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_release_quality_metrics` ;;

  dimension: release_key {
    type: string
    sql: ${TABLE}.release_key ;;
  }

  dimension: release_name {
    type: string
    sql: ${TABLE}.release_name ;;
  }

  dimension: gate_status {
    type: string
    sql: ${TABLE}.gate_status ;;
  }

  measure: open_critical_high_bugs {
    type: sum
    sql: ${TABLE}.open_critical_high_bugs ;;
  }

  measure: test_coverage_pct {
    type: average
    value_format_name: percent_1
    sql: ${TABLE}.test_coverage_pct ;;
  }

  measure: active_prod_errors {
    type: sum
    sql: ${TABLE}.active_prod_errors ;;
  }

  measure: active_prod_errors_high {
    type: sum
    sql: ${TABLE}.active_prod_errors_high ;;
  }
}
