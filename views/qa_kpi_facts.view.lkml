view: qa_kpi_facts {
  sql_table_name: `qa_metrics.qa_kpi_facts_enriched` ;;

  dimension: kpi_id {
    type: string
    sql: ${TABLE}.kpi_id ;;
  }

  dimension: kpi_name {
    type: string
    sql: ${TABLE}.kpi_name ;;
  }

  dimension: kpi_label {
    type: string
    sql: CONCAT(${kpi_id}, " - ", ${kpi_name}) ;;
  }

  dimension: privacy_level {
    type: string
    sql: ${TABLE}.privacy_level ;;
  }

  dimension: priority_label {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.priority_label, ''), '(unknown)') ;;
  }

  dimension_group: metric_date {
    type: time
    timeframes: [date, week, month, quarter, year]
    sql: ${TABLE}.metric_date ;;
  }

  # Dashboard date_filter passes TIMESTAMP boundaries.
  # BigQuery qa_kpi_facts.metric_date is DATE, so we expose a TIMESTAMP-typed time dimension for filtering.
  dimension_group: metric_ts {
    type: time
    timeframes: [raw, time, date, week, month, quarter, year]
    sql: TIMESTAMP(${TABLE}.metric_date) ;;
  }

  dimension: pod {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.pod, ''), '(unknown)') ;;
  }

  dimension: feature {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.feature, ''), '(unknown)') ;;
  }

  dimension: release {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.release, ''), '(unknown)') ;;
  }

  dimension: sprint {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.sprint, ''), '(unknown)') ;;
  }

  dimension: qa_user {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.qa_user, ''), '(unknown)') ;;
  }

  dimension: developer_user {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.developer_user, ''), '(unknown)') ;;
  }

  dimension: severity {
    type: string
    sql: COALESCE(NULLIF(${TABLE}.severity, ''), '(unknown)') ;;
  }

  dimension: unit {
    type: string
    sql: ${TABLE}.unit ;;
  }

  dimension: source {
    type: string
    sql: ${TABLE}.source ;;
  }

  measure: records {
    type: count
  }

  measure: numerator_sum {
    type: sum
    sql: ${TABLE}.numerator ;;
    value_format_name: decimal_2
  }

  measure: denominator_sum {
    type: sum
    sql: ${TABLE}.denominator ;;
    value_format_name: decimal_2
  }

  measure: manual_value_sum {
    type: sum
    sql: ${TABLE}.value ;;
    value_format_name: decimal_2
  }

  # Generic KPI value:
  # - If denominator is present: SUM(numerator) / SUM(denominator)
  # - Else: SUM(numerator) or SUM(value) (manual)
  measure: kpi_value {
    type: number
    sql:
      CASE
        WHEN SUM(${TABLE}.denominator) IS NULL OR SUM(${TABLE}.denominator) = 0 THEN
          COALESCE(SUM(${TABLE}.numerator), SUM(${TABLE}.value))
        ELSE
          SAFE_DIVIDE(SUM(${TABLE}.numerator), SUM(${TABLE}.denominator))
      END ;;
    value_format_name: decimal_2
  }

  measure: kpi_value_percent {
    type: number
    sql:
      CASE
        WHEN SUM(${TABLE}.denominator) IS NULL OR SUM(${TABLE}.denominator) = 0 THEN
          COALESCE(SUM(${TABLE}.numerator), SUM(${TABLE}.value))
        ELSE
          SAFE_DIVIDE(SUM(${TABLE}.numerator), SUM(${TABLE}.denominator))
      END ;;
    value_format_name: percent_2
  }
}
