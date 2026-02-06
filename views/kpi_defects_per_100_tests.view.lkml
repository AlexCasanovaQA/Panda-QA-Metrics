view: kpi_defects_per_100_tests {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_kpi_defects_per_100_tests` ;;

  dimension: release_key {
    type: string
    sql: ${TABLE}.release_key ;;
  }

  dimension: severity_bucket {
    type: string
    sql: ${TABLE}.severity_bucket ;;
  }

  dimension_group: release {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.release_end_ts ;;
  }

  measure: defects_created {
    type: sum
    sql: ${TABLE}.defects_created ;;
    value_format_name: decimal_0
  }

  measure: tests_executed {
    type: sum
    sql: ${TABLE}.tests_executed ;;
    value_format_name: decimal_0
  }

  measure: defects_per_100_tests {
    type: average
    sql: ${TABLE}.defects_per_100_tests ;;
    value_format_name: decimal_2
  }
}
