view: jira_mttr_fixed_daily {
  derived_table: {
    sql:
      SELECT
        DATE(resolutiondate) AS event_date,
        TIMESTAMP_DIFF(resolutiondate, created, HOUR) AS mttr_hours,
        issue_key
      FROM `qa_metrics.jira_issues_latest`
      WHERE LOWER(COALESCE(issue_type, '')) IN ('bug', 'defect')
        AND created IS NOT NULL
        AND resolutiondate IS NOT NULL
        AND LOWER(COALESCE(status_category, '')) = 'done' ;;
  }

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: TIMESTAMP(${TABLE}.event_date) ;;
  }

  measure: avg_mttr_hours {
    type: average
    sql: ${TABLE}.mttr_hours ;;
    value_format_name: decimal_2
  }

  measure: issues_in_cohort {
    type: count_distinct
    sql: ${TABLE}.issue_key ;;
  }
}
