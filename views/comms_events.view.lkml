view: comms_events {
  sql_table_name: `qa-panda-metrics.qa_metrics.comms_events` ;;

  primary_key: event_id

  dimension: event_id {
    type: string
    sql: ${TABLE}.event_id ;;
  }

  dimension: pod {
    type: string
    sql: ${TABLE}.pod ;;
  }

  dimension: qa_group {
    type: string
    sql: ${TABLE}.qa_group ;;
  }

  dimension: urgency {
    type: string
    sql: ${TABLE}.urgency ;;
  }

  dimension: event_type {
    type: string
    sql: ${TABLE}.event_type ;;
  }

  dimension: channel {
    type: string
    sql: ${TABLE}.channel ;;
  }

  dimension_group: request {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.request_ts ;;
  }

  dimension_group: response {
    type: time
    timeframes: [raw, date, week, month]
    sql: ${TABLE}.response_ts ;;
  }

  dimension: response_time_minutes {
    type: number
    sql: TIMESTAMP_DIFF(${TABLE}.response_ts, ${TABLE}.request_ts, MINUTE) ;;
    value_format_name: decimal_0
  }

  measure: events {
    type: count
  }

  measure: avg_response_minutes {
    type: average
    sql: ${response_time_minutes} ;;
    value_format_name: decimal_1
  }

  measure: p50_response_minutes {
    type: percentile
    sql: ${response_time_minutes} ;;
    percentile: 50
    value_format_name: decimal_0
  }

  measure: p90_response_minutes {
    type: percentile
    sql: ${response_time_minutes} ;;
    percentile: 90
    value_format_name: decimal_0
  }

  measure: flagged_events {
    type: count
    filters: [event_type: "FLAGGED"]
  }

  measure: response_events {
    type: count
    filters: [event_type: "RESPONSE"]
  }

  # KPI helpers
  measure: kpi_p41_avg_time_to_flag_minutes {
    label: "KPI P41 - Avg Time to Flag (min)"
    type: average
    sql: ${response_time_minutes} ;;
    filters: [event_type: "FLAGGED"]
    value_format_name: decimal_1
  }

  measure: kpi_p42_avg_response_time_minutes {
    label: "KPI P42 - Avg Response Time (min)"
    type: average
    sql: ${response_time_minutes} ;;
    filters: [event_type: "RESPONSE"]
    value_format_name: decimal_1
  }
}
