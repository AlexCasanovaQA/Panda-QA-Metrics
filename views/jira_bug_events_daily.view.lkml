view: jira_bug_events_daily {
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
        SELECT
          issue_key,
          COALESCE(NULLIF(priority, ''), 'Unspecified') AS priority_label,
          COALESCE(NULLIF(severity, ''), 'Unspecified') AS severity_label,
          COALESCE(NULLIF(team, ''), 'Unassigned') AS pod
        FROM `qa_metrics.jira_issues_latest`
        WHERE LOWER(COALESCE(issue_type, '')) IN ('bug', 'defect')
      ),
      status_events AS (
        SELECT
          sc.event_date,
          CASE
            WHEN sc.to_status_lc = 'reopened' THEN 'reopened'
            WHEN sc.to_status_lc IN ('fixed', 'claimed fixed', 'known shippable', 'resolved', 'closed', 'verified') THEN 'fixed'
            ELSE NULL
          END AS event_type,
          bd.priority_label,
          bd.severity_label,
          bd.pod,
          sc.issue_key
        FROM status_changes sc
        JOIN bug_dim bd USING (issue_key)
      )
      SELECT
        event_date,
        event_type,
        priority_label,
        severity_label,
        pod,
        COUNT(DISTINCT issue_key) AS bugs_count
      FROM status_events
      WHERE event_type IS NOT NULL
      GROUP BY 1,2,3,4,5 ;;
  }

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: TIMESTAMP(${TABLE}.event_date) ;;
  }

  dimension: event_type { type: string sql: ${TABLE}.event_type ;; }
  dimension: priority_label { type: string sql: ${TABLE}.priority_label ;; }
  dimension: severity_label { type: string sql: ${TABLE}.severity_label ;; }
  dimension: pod { label: "POD" type: string sql: ${TABLE}.pod ;; }

  measure: bugs {
    type: sum
    sql: ${TABLE}.bugs_count ;;
    value_format_name: decimal_0
  }
}
