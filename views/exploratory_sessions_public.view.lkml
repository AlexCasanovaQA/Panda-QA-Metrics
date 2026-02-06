view: exploratory_sessions_public {
  derived_table: {
    sql:
      SELECT
        session_date,
        pod,
        COALESCE(p.qa_group, 'unknown') AS qa_group,
        COUNT(1) AS sessions,
        SUM(hours) AS total_hours,
        SUM(CASE WHEN notes_link IS NOT NULL AND notes_link != '' THEN 1 ELSE 0 END) AS sessions_with_notes,
        SUM(CASE WHEN flagged_to_leads THEN 1 ELSE 0 END) AS flagged_sessions,
        SUM(issues_found) AS issues_found
      FROM `qa-panda-metrics.qa_metrics.exploratory_sessions` s
      LEFT JOIN `qa-panda-metrics.qa_metrics.dim_people` p
        ON s.person_key = p.person_key
      GROUP BY 1,2,3 ;;
  }

  dimension_group: session {
    type: time
    timeframes: [date, week, month]
    sql: ${TABLE}.session_date ;;
  }

  dimension: pod {
    type: string
    sql: ${TABLE}.pod ;;
  }

  dimension: qa_group {
    type: string
    sql: ${TABLE}.qa_group ;;
  }

  measure: sessions {
    type: sum
    sql: ${TABLE}.sessions ;;
  }

  measure: sessions_with_notes {
    type: sum
    sql: ${TABLE}.sessions_with_notes ;;
  }

  measure: reporting_coverage {
    type: number
    sql: SAFE_DIVIDE(${sessions_with_notes}, NULLIF(${sessions}, 0)) ;;
    value_format_name: percent_1
  }

  measure: flagged_sessions {
    type: sum
    sql: ${TABLE}.flagged_sessions ;;
  }

  measure: total_hours {
    type: sum
    sql: ${TABLE}.total_hours ;;
    value_format_name: decimal_2
  }

  measure: issues_found {
    type: sum
    sql: ${TABLE}.issues_found ;;
  }
}
