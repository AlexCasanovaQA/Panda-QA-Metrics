view: jira_active_bug_count_daily {
  derived_table: {
    sql:
      WITH bug_lifecycle AS (
        SELECT
          DATE(created) AS created_date,
          DATE(resolutiondate) AS resolved_date
        FROM `qa_metrics.jira_issues_latest`
        WHERE LOWER(COALESCE(issue_type, '')) IN ('bug', 'defect')
          AND created IS NOT NULL
      ),
      date_spine AS (
        SELECT day AS metric_date
        FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY), CURRENT_DATE())) AS day
      )
      SELECT
        ds.metric_date,
        COUNTIF(bl.created_date <= ds.metric_date AND (bl.resolved_date IS NULL OR bl.resolved_date > ds.metric_date)) AS active_bug_count
      FROM date_spine ds
      CROSS JOIN bug_lifecycle bl
      GROUP BY 1 ;;
  }

  dimension_group: metric_date {
    type: time
    timeframes: [date, week, month]
    sql: TIMESTAMP(${TABLE}.metric_date) ;;
  }

  measure: active_bug_count {
    type: max
    sql: ${TABLE}.active_bug_count ;;
    value_format_name: decimal_0
  }
}
