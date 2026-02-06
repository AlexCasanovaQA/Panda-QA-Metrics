view: kpi_dde_and_escape {
  sql_table_name: `qa-panda-metrics.qa_metrics.v_kpi_dde_and_escape` ;;

  dimension: release_key {
    type: string
    sql: ${TABLE}.release_key ;;
  }

  dimension: release_name {
    type: string
    sql: ${TABLE}.release_name ;;
  }

  dimension: severity_bucket {
    type: string
    sql: ${TABLE}.severity_bucket ;;
  }

  measure: pre_release_defects {
    type: sum
    sql: ${TABLE}.pre_release_defects ;;
  }

  measure: post_release_production_defects {
    type: sum
    sql: ${TABLE}.post_release_production_defects ;;
  }

  measure: total_defects {
    type: sum
    sql: ${TABLE}.total_defects ;;
  }

  measure: defect_detection_efficiency {
    type: average
    value_format_name: percent_1
    sql: ${TABLE}.dde ;;
  }

  measure: bug_escape_rate {
    type: average
    value_format_name: percent_1
    sql: ${TABLE}.escape_rate ;;
  }
}
