view: comms_events_public {
  derived_table: {
    sql:
      SELECT
        DATE(request_ts) AS request_date,
        FORMAT_DATE('%G-%V', DATE(request_ts)) AS request_iso_week,
        pod,
        qa_group,
        urgency,
        event_type,
        COUNT(1) AS events,
        AVG(TIMESTAMP_DIFF(response_ts, request_ts, MINUTE)) AS avg_minutes,
        APPROX_QUANTILES(TIMESTAMP_DIFF(response_ts, request_ts, MINUTE), 100)[OFFSET(50)] AS p50_minutes,
        APPROX_QUANTILES(TIMESTAMP_DIFF(response_ts, request_ts, MINUTE), 100)[OFFSET(90)] AS p90_minutes
      FROM `qa-panda-metrics.qa_metrics.comms_events`
      WHERE request_ts IS NOT NULL AND response_ts IS NOT NULL
      GROUP BY 1,2,3,4,5,6 ;;
  }

  dimension_group: request {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.request_date ;;
  }

  dimension: request_iso_week {
    type: string
    sql: ${TABLE}.request_iso_week ;;
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

  measure: events {
    type: sum
    sql: ${TABLE}.events ;;
  }

  measure: avg_minutes {
    type: average
    sql: ${TABLE}.avg_minutes ;;
    value_format_name: decimal_1
  }

  measure: p50_minutes {
    type: average
    sql: ${TABLE}.p50_minutes ;;
    value_format_name: decimal_1
  }

  measure: p90_minutes {
    type: average
    sql: ${TABLE}.p90_minutes ;;
    value_format_name: decimal_1
  }
}
