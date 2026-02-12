connection: "qa-panda-metrics-exp"

include: "/views/**/*.view.lkml"
include: "/dashboards/**/*.dashboard.lookml"


timezone: "UTC"

# User attribute required:
#  - qa_is_lead: set to "yes" for leads, anything else for normal users.
access_grant: qa_lead {
  user_attribute: qa_is_lead
  allowed_values: ["yes"]
}

explore: qa_kpi_facts {
  label: "QA KPIs"

  # Public users only see privacy_level='public'
  sql_always_where:
    {% if _user_attributes['qa_is_lead'] == 'yes' %}
      1=1
    {% else %}
      ${qa_kpi_facts.privacy_level} = "public"
    {% endif %} ;;

  join: kpi_catalog {
    type: left_outer
    relationship: many_to_one
    sql_on: ${qa_kpi_facts.kpi_id} = ${kpi_catalog.kpi_id} ;;
  }
}

# Optional: raw explores for deeper analysis (leads only)
explore: jira_issues_latest {
  label: "Jira Issues (Latest)"
  required_access_grants: [qa_lead]
}

explore: testrail_runs_latest {
  label: "TestRail Runs (Latest)"
  required_access_grants: [qa_lead]
}

explore: bugsnag_errors_latest {
  label: "Bugsnag Errors (Latest)"
  required_access_grants: [qa_lead]
}
