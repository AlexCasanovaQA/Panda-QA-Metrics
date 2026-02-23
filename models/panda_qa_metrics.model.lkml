connection: "qa-panda-metrics-exp"

include: "/views/qa_metrics/*.view.lkml"
include: "/dashboards/qa_metrics/*.dashboard.lookml"

# Core KPI explore (existing)
explore: qa_kpi_facts {
  label: "QA KPIs"
  description: "Unified KPI fact table (public + private)."
  from: qa_kpi_facts
}

# Executive / Ops explores
explore: jira_issues_latest { label: "Jira Issues (Latest)" }
explore: jira_bug_events_daily { label: "Jira Bug Events (Daily)" }
explore: jira_active_bug_count_daily { label: "Jira Active Bug Count (Daily)" }
explore: jira_fix_fail_rate_daily { label: "Jira Fix Fail Rate (Daily)" }
explore: jira_mttr_fixed_daily { label: "Jira MTTR to Fixed (Daily)" }

explore: testrail_runs_latest { label: "TestRail Runs (Latest)" }
explore: testrail_bvt_latest { label: "TestRail BVT (Latest)" }

explore: bugsnag_errors_latest { label: "BugSnag Errors (Latest)" }

explore: gamebench_daily_metrics { label: "GameBench Daily Metrics" }
explore: build_size_manual { label: "Build Size Manual" }
