view: jira_bug_events_daily {
  sql_table_name: `qa_metrics.jira_bug_events_daily` ;;

  dimension_group: event_date {
    type: time
    timeframes: [date, week, month]
    sql: TIMESTAMP(${TABLE}.event_date) ;;
  }

  dimension: event_type { type: string sql: ${TABLE}.event_type ;; }
  dimension: priority_label { type: string sql: ${TABLE}.priority_label ;; }
  dimension: severity_label {
    label: "Severity"
    type: string
    sql:
      CASE
        WHEN ${TABLE}.severity_label IS NULL OR TRIM(${TABLE}.severity_label) = '' THEN '(unknown)'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity_label), r'(s0|sev[\s_-]*0|blocker|showstopper)') THEN '(S0) Blocker'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity_label), r'(s1|sev[\s_-]*1|critical|high)') THEN '(S1) Critical'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity_label), r'(s2|sev[\s_-]*2|major|medium|moderate)') THEN '(S2) Major'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity_label), r'(s3|sev[\s_-]*3|minor|low)') THEN '(S3) Minor'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity_label), r'(s4|sev[\s_-]*4|trivial|lowest)') THEN '(S4) Trivial'
        ELSE ${TABLE}.severity_label
      END ;;
  }
  dimension: pod { label: "POD" type: string sql: ${TABLE}.pod ;; }

  measure: bugs {
    type: sum
    sql: ${TABLE}.bugs_count ;;
    value_format_name: decimal_0
  }
}
