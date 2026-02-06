view: release_quality {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_release_quality_metrics` ;;

  dimension: release_key {
    type: string
    sql: ${TABLE}.release_key ;;
  }

  dimension: release_name {
    type: string
    sql: ${TABLE}.release_name ;;
  }

  dimension_group: release_end {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.release_end_ts ;;
  }

  measure: qa_defects_created {
    type: sum
    sql: ${TABLE}.qa_defects_created ;;
    value_format_name: decimal_0
  }

  measure: prod_errors_new {
    type: sum
    sql: ${TABLE}.prod_errors_new ;;
    value_format_name: decimal_0
  }

  measure: tests_executed {
    type: sum
    sql: ${TABLE}.tests_executed ;;
    value_format_name: decimal_0
  }

  measure: tests_total {
    type: sum
    sql: ${TABLE}.tests_total ;;
    value_format_name: decimal_0
  }

  measure: test_coverage {
    type: average
    sql: ${TABLE}.test_coverage ;;
    value_format_name: percent_2
  }

  measure: open_crit_high_at_release_end {
    type: sum
    sql: ${TABLE}.open_crit_high_at_release_end ;;
    value_format_name: decimal_0
  }

  measure: active_critical_or_high_errors {
    type: sum
    sql: ${TABLE}.active_critical_or_high_errors ;;
    value_format_name: decimal_0
  }

  measure: quality_gate_pass {
    type: yesno
    sql: ${TABLE}.quality_gate_pass ;;
  }
}
