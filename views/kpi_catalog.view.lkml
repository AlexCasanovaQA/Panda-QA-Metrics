view: kpi_catalog {
  sql_table_name: `qa_metrics.kpi_catalog` ;;

  dimension: kpi_id {
    type: string
    primary_key: yes
    sql: ${TABLE}.kpi_id ;;
  }

  dimension: kpi_name {
    type: string
    sql: ${TABLE}.kpi_name ;;
  }

  dimension: privacy_level {
    type: string
    sql: ${TABLE}.privacy_level ;;
  }

  dimension: section {
    type: string
    sql: ${TABLE}.section ;;
  }

  dimension: subsection {
    type: string
    sql: ${TABLE}.subsection ;;
  }

  dimension: kpi_type {
    type: string
    sql: ${TABLE}.kpi_type ;;
  }

  dimension: qa_group_scope {
    type: string
    sql: ${TABLE}.qa_group_scope ;;
  }

  dimension: description {
    type: string
    sql: ${TABLE}.description ;;
  }

  dimension: data_sources {
    type: string
    sql: ${TABLE}.data_sources ;;
  }

  dimension: calculation {
    type: string
    sql: ${TABLE}.calculation ;;
  }

  dimension: granularity {
    type: string
    sql: ${TABLE}.granularity ;;
  }

  dimension: time_window {
    type: string
    sql: ${TABLE}.time_window ;;
  }

  dimension: target_threshold {
    type: string
    sql: ${TABLE}.target_threshold ;;
  }

  dimension: owner_role {
    type: string
    sql: ${TABLE}.owner_role ;;
  }

  dimension: notes_looker_usage {
    type: string
    sql: ${TABLE}.notes_looker_usage ;;
  }

  dimension: automation {
    type: string
    sql: ${TABLE}.automation ;;
  }
}
