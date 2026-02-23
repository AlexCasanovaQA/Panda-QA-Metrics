connection: "qa-panda-metrics-exp"

include: "/scopely_panda/views/qa_metrics/*.view.lkml"
include: "/scopely_panda/dashboards/qa_metrics/*.dashboard.lookml"


# Existing KPI explore (used by QA KPIs dashboards)
explore: qa_kpi_facts {
  from: qa_kpi_facts
  label: "QA KPI Facts"
}
# Base explore (legacy dashboards use this name)
explore: qa_kpi_facts {
  label: "QA KPIs"
  description: "Unified KPI fact table (public + private)."
  from: qa_kpi_facts
}

# Alias explore (some dashboards/listeners reference this name)
explore: panda_qa_kpi_facts {
  label: "QA KPIs (alias)"
  description: "Alias explore for dashboards that reference panda_qa_kpi_facts.* fields."
  from: qa_kpi_facts
}
