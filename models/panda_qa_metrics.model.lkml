connection: "qa-panda-metrics-exp"

include: "/views/qa_metrics/*.view.lkml"
include: "/dashboards/qa_metrics/*.dashboard.lookml"


explore: qa_kpi_facts {
  label: "QA KPIs"
  description: "Unified KPI fact table (public + private)."
  from: qa_kpi_facts
}
