view: bugsnag_errors_latest {
  sql_table_name: `qa_metrics.bugsnag_errors_latest` ;;

  dimension: error_key {
    type: string
    primary_key: yes
    sql: CONCAT(${TABLE}.project_id, ":", ${TABLE}.error_id) ;;
  }

  dimension: project_id { type: string sql: ${TABLE}.project_id ;; }
  dimension: error_id { type: string sql: ${TABLE}.error_id ;; }
  dimension: error_class { type: string sql: ${TABLE}.error_class ;; }
  dimension: message { type: string sql: ${TABLE}.message ;; }
  dimension: severity { type: string sql: ${TABLE}.severity ;; }
  dimension: status { type: string sql: ${TABLE}.status ;; }

  dimension_group: first_seen {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.first_seen ;;
  }

  dimension_group: last_seen {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.last_seen ;;
  }

  dimension: events { type: number sql: ${TABLE}.events ;; }
  dimension: users { type: number sql: ${TABLE}.users ;; }

    dimension: is_active {
    type: yesno
    sql: LOWER(IFNULL(${status}, '')) NOT IN ('resolved','closed') ;;
  }

  measure: errors { type: count }

  measure: events_sum {
    type: sum
    sql: ${events} ;;
  }

  measure: users_sum {
    type: sum
    sql: ${users} ;;
  }

  measure: active_errors {
    type: count
    filters: [is_active: "yes"]
  }

  measure: high_critical_active_errors {
    type: count
    filters: [is_active: "yes", severity: "critical,error"]
  }
}
