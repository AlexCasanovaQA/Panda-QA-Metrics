view: kpi_escape_rate_and_dde {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_kpi_escape_rate_and_dde` ;;

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

  measure: pre_release_defects {
    type: sum
    sql: ${TABLE}.pre_release_defects ;;
    value_format_name: decimal_0
  }

  measure: post_release_production_defects {
    type: sum
    sql: ${TABLE}.post_release_production_defects ;;
    value_format_name: decimal_0
  }

  measure: total_defects {
    type: sum
    sql: ${TABLE}.total_defects ;;
    value_format_name: decimal_0
  }

  measure: bug_escape_rate {
    type: average
    sql: ${TABLE}.bug_escape_rate ;;
    value_format_name: percent_2
  }

  measure: defect_detection_efficiency {
    type: average
    sql: ${TABLE}.defect_detection_efficiency ;;
    value_format_name: percent_2
  }
}
