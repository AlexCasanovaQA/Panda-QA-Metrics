view: os_expectations {
  sql_table_name: `qa-panda-metrics.qa_metrics.os_expectations` ;;

  primary_key: week_start

  dimension_group: week_start {
    type: time
    timeframes: [date, week]
    sql: ${TABLE}.week_start ;;
  }

  dimension_group: week_end {
    type: time
    timeframes: [date]
    sql: ${TABLE}.week_end ;;
  }

  dimension: pod {
    type: string
    sql: ${TABLE}.pod ;;
  }

  dimension: expected_hands_on_pct {
    type: number
    sql: ${TABLE}.expected_hands_on_pct ;;
    value_format_name: percent_1
  }

  dimension: expected_total_hours {
    type: number
    sql: ${TABLE}.expected_total_hours ;;
    value_format_name: decimal_0
  }

  dimension: notes {
    type: string
    sql: ${TABLE}.notes ;;
  }

  measure: rows {
    type: count
  }
}
