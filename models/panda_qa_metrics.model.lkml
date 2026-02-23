connection: "qa-panda-metrics-exp"

include: "/scopely_panda/views/qa_metrics/*.view.lkml"
include: "/scopely_panda/dashboards/qa_metrics/*.dashboard.lookml"

# Primary KPI explore
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

# Dashboard-specific explores
explore: jira_issues_latest { from: jira_issues_latest }
explore: jira_bug_events_daily { from: jira_bug_events_daily }
explore: jira_fix_fail_rate_daily { from: jira_fix_fail_rate_daily }
explore: jira_mttr_fixed_daily { from: jira_mttr_fixed_daily }
explore: jira_active_bug_count_daily { from: jira_active_bug_count_daily }
explore: build_size_manual { from: build_size_manual }
explore: testrail_runs_latest { from: testrail_runs_latest }
explore: testrail_bvt_latest { from: testrail_bvt_latest }
explore: bugsnag_errors_latest { from: bugsnag_errors_latest }
explore: gamebench_daily_metrics { from: gamebench_daily_metrics }
