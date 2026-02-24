view: jira_issues_latest {
  sql_table_name: `qa_metrics.jira_issues_latest` ;;

  dimension: issue_key { type: string primary_key: yes sql: ${TABLE}.issue_key ;; }
  dimension: id { type: string sql: ${TABLE}.id ;; }
  dimension: project_key { type: string sql: ${TABLE}.project_key ;; }
  dimension: summary { type: string sql: ${TABLE}.summary ;; }
  dimension: description_plain { type: string sql: ${TABLE}.description_plain ;; }

  dimension: issue_type { type: string sql: ${TABLE}.issue_type ;; }
  dimension: status { type: string sql: ${TABLE}.status ;; }
  dimension: qa_verification_state {
    type: string
    sql:
      CASE
        WHEN REGEXP_CONTAINS(
          LOWER(COALESCE(${TABLE}.status, '')),
          r'(ready\\s*for\\s*qa|in\\s*qa|awaiting\\s*qa\\s*verification|qa\\s*verification|qa\\s*review|ready\\s*for\\s*verification|in\\s*verification)'
        ) THEN 'QA Verification'
        ELSE 'Other'
      END ;;
    description: "Normalized QA verification state based on Jira status patterns to avoid project-specific hardcoded status lists in dashboards."
  }
  dimension: regression_state {
    type: string
    sql:
      CASE
        WHEN REGEXP_CONTAINS(
          LOWER(COALESCE(${TABLE}.status, '')),
          r'(ready\s*for\s*regression|awaiting\s*regression|in\s*regression|retest)'
        ) THEN 'Regression'
        ELSE 'Other'
      END ;;
    description: "Normalized regression testing state based on Jira status patterns to avoid project-specific hardcoded status lists in dashboards."
  }
  dimension: status_category { type: string sql: ${TABLE}.status_category ;; }
  dimension: priority { type: string sql: ${TABLE}.priority ;; }
  dimension: severity { type: string sql: ${TABLE}.severity ;; }
  dimension: severity_normalized {
    label: "Severity"
    type: string
    order_by_field: severity_sort_order
    sql:
      CASE
        WHEN ${TABLE}.severity IS NULL OR TRIM(${TABLE}.severity) = '' THEN '(unknown)'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity), r'(s0|sev[\s_-]*0|blocker|showstopper)') THEN '(S0) Blocker'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity), r'(s1|sev[\s_-]*1|critical|high)') THEN '(S1) Critical'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity), r'(s2|sev[\s_-]*2|major|medium|moderate)') THEN '(S2) Major'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity), r'(s3|sev[\s_-]*3|minor|low)') THEN '(S3) Minor'
        WHEN REGEXP_CONTAINS(LOWER(${TABLE}.severity), r'(s4|sev[\s_-]*4|trivial|lowest)') THEN '(S4) Trivial'
        ELSE ${TABLE}.severity
      END ;;
    description: "Normalized Jira severity bucket for executive reporting. Maps Jira variants to canonical labels: (S0) Blocker, (S1) Critical, (S2) Major, (S3) Minor, (S4) Trivial."
  }

  dimension: severity_sort_order {
    hidden: yes
    type: number
    sql:
      CASE
        WHEN ${severity_normalized} = '(S0) Blocker' THEN 1
        WHEN ${severity_normalized} = '(S1) Critical' THEN 2
        WHEN ${severity_normalized} = '(S2) Major' THEN 3
        WHEN ${severity_normalized} = '(S3) Minor' THEN 4
        WHEN ${severity_normalized} = '(S4) Trivial' THEN 5
        WHEN ${severity_normalized} = '(unknown)' THEN 99
        ELSE 50
      END ;;
  }

  dimension: assignee { type: string sql: ${TABLE}.assignee ;; }
  dimension: reporter { type: string sql: ${TABLE}.reporter ;; }

  dimension: team { label: "POD" type: string sql: ${TABLE}.team ;; }
  dimension: sprint { type: string sql: ${TABLE}.sprint ;; }
  dimension: fix_versions { type: string sql: ${TABLE}.fix_versions ;; }
  dimension: components { type: string sql: ${TABLE}.components ;; }
  dimension: labels { type: string sql: ${TABLE}.labels ;; }

  dimension: story_points { type: number sql: ${TABLE}.story_points ;; }

  dimension_group: created {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.created ;;
  }

  dimension_group: updated {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.updated ;;
  }

  dimension_group: resolutiondate {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.resolutiondate ;;
  }

  dimension: resolution { type: string sql: ${TABLE}.resolution ;; }

  measure: issues { type: count }
}
