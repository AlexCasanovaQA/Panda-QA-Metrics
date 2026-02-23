- dashboard: qa_executive
  title: QA Executive
  layout: newspaper
  preferred_viewer: dashboards-next
  description: "Executive QA dashboard with curated KPI definitions, clearer visual hierarchy, and consistent chart sizing/colors (Jira + TestRail + BugSnag + GameBench)."
  refresh: 15 minutes

  filters:
  - name: date_range
    title: Date Range
    type: date_filter
    default_value: 7 days

  - name: pod
    title: POD
    type: field_filter
    model: panda_qa_metrics
    explore: jira_issues_latest
    field: jira_issues_latest.team

  - name: priority
    title: Priority
    type: field_filter
    model: panda_qa_metrics
    explore: jira_issues_latest
    field: jira_issues_latest.priority

  - name: severity
    title: Severity
    type: field_filter
    model: panda_qa_metrics
    explore: jira_issues_latest
    field: jira_issues_latest.severity

  - name: env
    title: GameBench Environment
    type: field_filter
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    field: gamebench_daily_metrics.environment

  - name: platform
    title: GameBench Platform
    type: field_filter
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    field: gamebench_daily_metrics.platform

  elements:
  - name: header_scoreboard
    type: text
    title_text: "QA Executive Scoreboard"
    body_text: "Top KPIs (current state): incident inflow, throughput and live backlog. Cada métrica incluye nota informativa (ícono i) con definición y cálculo."

  - name: bugs_entered_today
    title: Bugs entered today
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "today"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: número de bugs/defects creados hoy en Jira. CÁLCULO: COUNT(issue_key) con filtros issue_type in (Bug, Defect) y created_date=today. USO: detectar picos de entrada diarios y comparar contra capacidad de triage/fix."
    row: 3
    col: 0
    width: 3
    height: 3

  - name: fixes_today
    title: Fixes today (Fixed)
    type: single_value
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "fixed"
      jira_bug_events_daily.event_date_date: "today"
    note_text: "DEFINICIÓN: bugs que cambiaron a estado Fixed hoy. CÁLCULO: COUNT de eventos de changelog con event_type=fixed y event_date=today. NOTA: esta tarjeta mantiene ventana fija diaria y no depende del filtro global date_range."
    row: 3
    col: 3
    width: 3
    height: 3

  - name: active_bugs_now
    title: Active bugs now
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: backlog activo de bugs en este momento. CÁLCULO: COUNT de issues con statusCategory != Done. USO: medir presión operativa actual y volumen pendiente de cierre."
    row: 3
    col: 6
    width: 3
    height: 3

  - name: qa_verification_queue_now
    title: QA verification queue now
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.qa_verification_state: "QA Verification"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: cola actual de validación QA. CÁLCULO: COUNT de bugs con qa_verification_state='QA Verification' (normaliza estados como Ready for QA, In QA, Awaiting QA Verification)."
    row: 3
    col: 9
    width: 3
    height: 3

  - name: awaiting_regression_now
    title: Awaiting regression now
    type: single_value
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status: "Ready for Regression,In Regression"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: bugs esperando o ejecutando regresión. CÁLCULO: COUNT con status in (Ready for Regression, In Regression). USO: evaluar carga de pruebas de regresión en curso."
    row: 3
    col: 12
    width: 3
    height: 3

  - name: header_incoming
    type: text
    title_text: "Incoming defects"
    body_text: "Análisis de volumen de entrada de bugs por severidad y prioridad, con proporciones y tendencia diaria."
    row: 6
    col: 0
    width: 16
    height: 2

  - name: entered_by_severity_7d
    title: Entered (last 7d) by Severity
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "7 days"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: distribución porcentual de bugs creados en los últimos 7 días por severidad. CÁLCULO: COUNT bugs grouped by severity con ventana rolling de 7 días."
    series_colors: {critical: "#D64550", high: "#F28B30", medium: "#F2C94C", low: "#2D9CDB"}
    row: 8
    col: 0
    width: 8
    height: 6

  - name: entered_by_severity_30d
    title: Entered (last 30d) by Severity
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.severity, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "30 days"
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: distribución porcentual de bugs creados en los últimos 30 días por severidad. CÁLCULO: COUNT bugs grouped by severity con ventana rolling de 30 días."
    series_colors: {critical: "#D64550", high: "#F28B30", medium: "#F2C94C", low: "#2D9CDB"}
    row: 8
    col: 8
    width: 8
    height: 6


  - name: incoming_bugs_created_daily_by_priority
    title: Incoming bugs created daily (last 7d)
    type: looker_column
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.created_date, jira_issues_latest.priority, jira_issues_latest.issues]
    pivots: [jira_issues_latest.priority]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.created_date: "7 days"
    sorts: [jira_issues_latest.created_date]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: tendencia diaria de bugs entrantes por prioridad (últimos 7 días). CÁLCULO: COUNT bugs por created_date y priority. USO: detectar si la entrada crítica sube más rápido que la capacidad de resolución."
    series_colors: {Highest: "#D64550", High: "#F28B30", Medium: "#F2C94C", Low: "#2D9CDB", Lowest: "#6FCF97"}
    row: 14
    col: 0
    width: 16
    height: 6

  - name: fixed_by_priority_7d
    title: Fixed (last 7d) by Priority
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "fixed"
      jira_bug_events_daily.event_date_date: "7 days"
    sorts: [jira_bug_events_daily.bugs desc]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "DEFINICIÓN: distribución de bugs corregidos en 7 días por prioridad. CÁLCULO: COUNT eventos fixed agrupados por priority_label con ventana 7 días."
    row: 20
    col: 0
    width: 8
    height: 6

  - name: fixed_by_priority_30d
    title: Fixed (last 30d) by Priority
    type: looker_pie
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.priority_label, jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "fixed"
      jira_bug_events_daily.event_date_date: "30 days"
    sorts: [jira_bug_events_daily.bugs desc]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "DEFINICIÓN: distribución de bugs corregidos en 30 días por prioridad. CÁLCULO: COUNT eventos fixed agrupados por priority_label con ventana 30 días."
    row: 20
    col: 8
    width: 8
    height: 6

  - name: active_bugs_by_pod
    title: Active bugs by POD
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.team, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: backlog activo repartido por POD/equipo. CÁLCULO: COUNT bugs activos (statusCategory != Done) agrupados por team. USO: balancear carga entre pods."
    row: 26
    col: 0
    width: 8
    height: 6

  - name: active_bugs_by_priority
    title: Active bugs by Priority
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.priority, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: backlog activo por prioridad actual. CÁLCULO: COUNT bugs activos agrupados por priority. USO: validar mezcla de criticidad pendiente."
    row: 26
    col: 8
    width: 8
    height: 6

  - name: bugs_by_current_status
    title: Bugs by current status
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.status, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: distribución de bugs por estado Jira actual. CÁLCULO: COUNT bugs agrupados por status. USO: identificar cuellos de botella en flujo QA/dev."
    row: 32
    col: 0
    width: 8
    height: 6

  - name: active_bug_count_over_time
    title: Active bug count over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_active_bug_count_daily
    fields: [jira_active_bug_count_daily.metric_date_date, jira_active_bug_count_daily.active_bug_count]
    sorts: [jira_active_bug_count_daily.metric_date_date]
    listen:
      date_range: jira_active_bug_count_daily.metric_date_date
    note_text: "DEFINICIÓN: evolución diaria del inventario de bugs activos. CÁLCULO: snapshot diario active_bug_count por fecha. USO: ver si backlog converge o diverge."
    series_colors: {jira_active_bug_count_daily.active_bug_count: "#2F80ED"}
    row: 32
    col: 8
    width: 8
    height: 6

  - name: reopened_over_time
    title: Reopened over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_bug_events_daily
    fields: [jira_bug_events_daily.event_date_date, jira_bug_events_daily.bugs]
    filters:
      jira_bug_events_daily.event_type: "reopened"
    sorts: [jira_bug_events_daily.event_date_date]
    listen:
      date_range: jira_bug_events_daily.event_date_date
    note_text: "DEFINICIÓN: bugs reabiertos por día. CÁLCULO: COUNT eventos changelog con event_type=reopened por fecha. USO: proxy de calidad de fix y escapes funcionales."
    series_colors: {jira_bug_events_daily.bugs: "#EB5757"}
    row: 38
    col: 0
    width: 8
    height: 6

  - name: fix_version_proxy_milestone
    title: Fix Version (proxy milestone)
    type: looker_bar
    model: panda_qa_metrics
    explore: jira_issues_latest
    fields: [jira_issues_latest.fix_versions, jira_issues_latest.issues]
    filters:
      jira_issues_latest.issue_type: "Bug,Defect"
      jira_issues_latest.status_category: "-Done"
    sorts: [jira_issues_latest.issues desc]
    listen:
      pod: jira_issues_latest.team
      priority: jira_issues_latest.priority
      severity: jira_issues_latest.severity
    note_text: "DEFINICIÓN: bugs activos por fixVersion (hito proxy). CÁLCULO: COUNT bugs activos agrupados por fix_versions. USO: priorización por release/milestone."
    row: 38
    col: 8
    width: 8
    height: 6

  - name: header_bugsnag
    type: text
    title_text: "BugSnag"
    body_text: "Estabilidad en producción: volumen activo y severidad de errores de BugSnag."
    row: 44
    col: 0
    width: 16
    height: 2

  - name: bugsnag_active_errors
    title: Active production errors
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.active_errors]
    note_text: "DEFINICIÓN: errores de producción activos no cerrados. CÁLCULO: COUNT errores donde status no está en resolved/closed."
    row: 46
    col: 0
    width: 4
    height: 3

  - name: bugsnag_high_critical_active
    title: High/Critical active errors
    type: single_value
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.high_critical_active_errors]
    note_text: "DEFINICIÓN: subconjunto de errores activos de mayor impacto. CÁLCULO: COUNT errores activos con severity in (critical,error)."
    row: 46
    col: 4
    width: 4
    height: 3

  - name: bugsnag_active_by_severity
    title: Active errors by severity
    type: looker_pie
    model: panda_qa_metrics
    explore: bugsnag_errors_latest
    fields: [bugsnag_errors_latest.severity, bugsnag_errors_latest.active_errors]
    note_text: "DEFINICIÓN: composición de errores activos por severidad. CÁLCULO: COUNT active_errors grouped by severity. USO: entender perfil de riesgo actual."
    series_colors: {critical: "#D64550", error: "#F28B30", warning: "#F2C94C", info: "#56CCF2"}
    row: 46
    col: 8
    width: 8
    height: 6

  - name: header_gamebench
    type: text
    title_text: "GameBench"
    body_text: "Performance de juego: snapshots actuales y tendencia por plataforma/entorno."
    row: 52
    col: 0
    width: 16
    height: 2

  - name: current_fps_by_platform
    title: Current snapshot | FPS by platform (latest day)
    type: looker_grid
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.platform, gamebench_daily_metrics.median_fps]
    filters:
      gamebench_daily_metrics.metric_date_date: "1 days"
    sorts: [gamebench_daily_metrics.metric_date_date desc, gamebench_daily_metrics.platform]
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_text: "DEFINICIÓN: snapshot de FPS mediana por plataforma en el día más reciente disponible. CÁLCULO: median_fps para metric_date dentro de 1 día."
    row: 54
    col: 0
    width: 8
    height: 5

  - name: current_session_stability
    title: Current KPI | Session stability (proxy)
    type: single_value
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.fps_stability_pct]
    filters:
      gamebench_daily_metrics.metric_date_date: "1 days"
    listen:
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_text: "DEFINICIÓN: proxy de estabilidad de sesión actual. CÁLCULO: fps_stability_pct en la fecha más reciente. NOTA: se usa como proxy ante ausencia de crash-free sessions en este explore."
    row: 54
    col: 8
    width: 8
    height: 5

  - name: gb_median_fps_7d
    title: Trend | Median FPS by platform
    type: looker_line
    model: panda_qa_metrics
    explore: gamebench_daily_metrics
    fields: [gamebench_daily_metrics.metric_date_date, gamebench_daily_metrics.median_fps, gamebench_daily_metrics.platform]
    pivots: [gamebench_daily_metrics.platform]
    sorts: [gamebench_daily_metrics.metric_date_date]
    listen:
      date_range: gamebench_daily_metrics.metric_date_date
      env: gamebench_daily_metrics.environment
      platform: gamebench_daily_metrics.platform
    note_text: "DEFINICIÓN: tendencia de FPS mediana diaria por plataforma. CÁLCULO: median_fps por fecha con pivot platform, gobernado por date_range global."
    series_colors: {Android: "#27AE60", iOS: "#2D9CDB"}
    row: 59
    col: 0
    width: 16
    height: 6

  - name: header_ops
    type: text
    title_text: "Operational QA metrics"
    body_text: "Métricas operativas QA: calidad del fix, velocidad de resolución, tamaño de build y ejecución de pruebas."
    row: 65
    col: 0
    width: 16
    height: 2

  - name: jira_fix_fail_rate_trend
    title: Trend | Fix fail rate over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_fix_fail_rate_daily
    fields: [jira_fix_fail_rate_daily.event_date_date, jira_fix_fail_rate_daily.fix_fail_rate]
    sorts: [jira_fix_fail_rate_daily.event_date_date]
    listen:
      date_range: jira_fix_fail_rate_daily.event_date_date
    note_text: "DEFINICIÓN: fix fail rate diario. CÁLCULO: reopened/fixed por día. INTERPRETACIÓN: cuanto más alto, más fixes regresan por regresión o cobertura insuficiente."
    series_colors: {jira_fix_fail_rate_daily.fix_fail_rate: "#EB5757"}
    row: 67
    col: 0
    width: 8
    height: 6

  - name: jira_mttr_hours_trend
    title: Trend | MTTR (hours) over time
    type: looker_line
    model: panda_qa_metrics
    explore: jira_mttr_claimed_fixed_daily
    fields: [jira_mttr_claimed_fixed_daily.event_date_date, jira_mttr_claimed_fixed_daily.avg_mttr_hours]
    filters:
      jira_mttr_claimed_fixed_daily.event_date_date: "7 days"
    sorts: [jira_mttr_claimed_fixed_daily.event_date_date]
    listen:
      date_range: jira_mttr_claimed_fixed_daily.event_date_date
    note_text: "DEFINICIÓN: MTTR operativo diario en horas. CÁLCULO: promedio(primera transición a Resolved/Closed/Verified - created_at), agregado por fecha de claimed fixed."
    series_colors: {jira_mttr_claimed_fixed_daily.avg_mttr_hours: "#9B51E0"}
    row: 67
    col: 8
    width: 8
    height: 6

  - name: current_build_size_by_platform
    title: Current snapshot | Build size by platform
    type: looker_grid
    model: panda_qa_metrics
    explore: build_size_manual
    fields: [build_size_manual.metric_date_date, build_size_manual.platform, build_size_manual.environment, build_size_manual.build_version, build_size_manual.build_size_mb]
    filters:
      build_size_manual.metric_date_date: "7 days"
    sorts: [build_size_manual.metric_date_date desc, build_size_manual.platform]
    note_text: "DEFINICIÓN: tamaño de build más reciente por plataforma/entorno. CÁLCULO: snapshot desde tabla manual en ventana de 7 días ordenada por fecha desc."
    row: 73
    col: 0
    width: 8
    height: 4

  - name: build_size_mb_trend
    title: Trend | Build size (MB) over time
    type: looker_line
    model: panda_qa_metrics
    explore: build_size_manual
    fields: [build_size_manual.metric_date_date, build_size_manual.build_size_mb, build_size_manual.platform]
    pivots: [build_size_manual.platform]
    sorts: [build_size_manual.metric_date_date]
    listen:
      date_range: build_size_manual.metric_date_date
    note_text: "DEFINICIÓN: evolución del tamaño de build en MB por plataforma. CÁLCULO: build_size_mb por fecha con pivot por platform."
    series_colors: {Android: "#27AE60", iOS: "#2D9CDB"}
    row: 77
    col: 0
    width: 8
    height: 6

  - name: header_testrail
    type: text
    title_text: "TestRail"
    body_text: "Salud de ejecución TestRail: throughput diario y señal de calidad del último run/build."
    row: 73
    col: 8
    width: 8
    height: 2

  - name: testcases_completed_by_day_7d
    title: Trend | Test cases completed by day
    type: looker_line
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.executed_cases]
    filters:
      testrail_runs_latest.is_completed: "yes"
    sorts: [testrail_runs_latest.completed_on_date]
    listen:
      date_range: testrail_runs_latest.completed_on_date
    note_text: "DEFINICIÓN: casos ejecutados por día (excluye untested). CÁLCULO: passed+failed+blocked+retest por completed_on, controlado por date_range global."
    series_colors: {testrail_runs_latest.executed_cases: "#2D9CDB"}
    row: 75
    col: 8
    width: 8
    height: 4

  - name: current_pass_rate
    title: Current KPI | Pass rate (latest run)
    type: single_value
    model: panda_qa_metrics
    explore: testrail_runs_latest
    fields: [testrail_runs_latest.completed_on_date, testrail_runs_latest.pass_rate]
    filters:
      testrail_runs_latest.is_completed: "yes"
    sorts: [testrail_runs_latest.completed_on_date desc, testrail_runs_latest.run_id desc]
    limit: 1
    listen:
      date_range: testrail_runs_latest.completed_on_date
    note_text: "DEFINICIÓN: pass rate del último run completado. CÁLCULO: SUM(passed)/SUM(passed+failed+blocked+retest) tomando run más reciente por completed_on y run_id."
    row: 79
    col: 8
    width: 4
    height: 3

  - name: bvt_pass_rate_latest_build
    title: Current KPI | BVT pass rate (latest build)
    type: single_value
    model: panda_qa_metrics
    explore: testrail_bvt_latest
    fields: [testrail_bvt_latest.completed_on_date, testrail_bvt_latest.pass_rate]
    sorts: [testrail_bvt_latest.completed_on_date desc, testrail_bvt_latest.run_id desc]
    limit: 1
    listen:
      date_range: testrail_bvt_latest.completed_on_date
    note_text: "DEFINICIÓN: pass rate BVT del último build/run disponible. CÁLCULO: pass_rate calculado en testrail_bvt_latest para el registro más reciente."
    row: 79
    col: 12
    width: 4
    height: 3
