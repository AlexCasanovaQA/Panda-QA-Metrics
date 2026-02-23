view: jira_fix_fail_rate_daily {
  derived_table: {
    sql:
      WITH status_changes AS (
        SELECT
          issue_key,
          DATE(changed_at) AS event_date,
          LOWER(COALESCE(to_status, '')) AS to_status_lc
        FROM `qa_metrics.jira_status_changes`
      ),
      bug_dim AS (
        SELECT issue_key
        FROM `qa_metrics.jira_issues_latest`
        WHERE LOWER(COALESCE(issue_type, '')) IN ('bug', 'defect')
      ),
      daily AS (
        SELECT
          sc.event_date,
          COUNT(DISTINCT IF(sc.to_status_lc IN ('fixed', 'claimed fixed', 'known shippable', 'resolved', 'closed', 'verified'), sc.issue_key, NULL)) AS fixed_count,
          COUNT(DISTINCT IF(sc.to_status_lc = 'reopened', sc.issue_key, NULL)) AS reopened_count
        FROM status_changes sc
        JOIN bug_dim bd USING (issue_key)
        GROUP BY 1
      )
      SELECT
        event_date,
        fixed_count,
        reopened_count
      FROM daily ;;
  }

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: TIMESTAMP(${TABLE}.event_date) ;;
  }

  dimension: fixed_count { type: number sql: ${TABLE}.fixed_count ;; }
  dimension: reopened_count { type: number sql: ${TABLE}.reopened_count ;; }

  measure: fixed {
    type: sum
    sql: ${fixed_count} ;;
    value_format_name: decimal_0
  }

  measure: reopened {
    type: sum
    sql: ${reopened_count} ;;
    value_format_name: decimal_0
  }

  measure: fix_fail_rate {
    type: number
    sql: SAFE_DIVIDE(SUM(${reopened_count}), NULLIF(SUM(${fixed_count}),0)) ;;
    value_format_name: percent_2
  }
}
