view: testrail_bvt_latest {
  sql_table_name: `qa_metrics.testrail_bvt_latest` ;;

  dimension: run_id { type: number primary_key: yes sql: ${TABLE}.run_id ;; }
  dimension: name {
    type: string
    sql: ${TABLE}.name ;;
    description: "Latest completed TestRail run tagged as BVT/Smoke/Sanity by name."
  }

  dimension_group: completed_on {
    type: time
    timeframes: [raw, date]
    sql: ${TABLE}.completed_on ;;
  }

  measure: pass_rate {
    type: number
    sql: AVG(${TABLE}.pass_rate_calc) ;;
    value_format_name: percent_2
  }
}
