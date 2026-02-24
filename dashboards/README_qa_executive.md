# QA Executive dashboard metric definitions (canonical)

Use these definitions in dashboard tile `note_text` so executives see one consistent interpretation.

## Timezone (applies to all metrics)
- **Timezone:** `UTC`.
- Daily windows, `today`, and rolling windows (7d/30d) are interpreted in UTC.

## Status mapping used for fix/reopen logic
From `qa_metrics.jira_status_category_map`:
- **done_or_fixed:** `resolved`, `closed`, `verified`, `done`, `fixed`, `completed`, `qa approved`, `ready for release`
- **reopened_target (active workflow):** `open`, `reopened`, `backlog`, `to do`, `in progress`, `selected for development`, `in review`, `ready for qa`, `ready for test`, `qa testing`, `testing`

Matching is case-insensitive and whitespace-tolerant (`LOWER(TRIM(status))`).

## Canonical metric terms
- **Entered:** bug/defect issues with `created_date` in the selected window (UTC).
- **Fixed:** bug issues with a status transition **into** `done_or_fixed` in the selected window (UTC). In changelog-based metrics this is event type `fixed`.
- **Claimed fixed:** first timestamp an issue transitions into `done_or_fixed`; this date defines MTTR cohorting.
- **Active:** current bug backlog where current Jira `statusCategory != Done`.
- **Reopened:** status transition from `done_or_fixed` **to** `reopened_target` in the selected window (UTC).

## Fix fail rate (canonical formula)
- **Formula:** `Fix fail rate = reopened_count / fixed_count`.
- **Denominator window:** denominator uses the **same aggregation window** as the numerator.
  - Daily trend point: same UTC day (`fixed_count` on that day).
  - Multi-day rollup: summed fixed events over the selected UTC date range.
- Use `SAFE_DIVIDE` / null-if-zero behavior when fixed count is 0.

## MTTR (claimed fixed) (canonical formula)
- **Formula:** `MTTR_hours = AVG((claimed_fixed_at - created_at) in hours)`.
- **Cohort/window:** reported by `DATE(claimed_fixed_at)`; executive tile is fixed to last 7 UTC days.
- **Stale/outlier guard:**
  - Exclude invalid negative durations (`claimed_fixed_at >= created_at` required).
  - Outlier trimming is **not** applied in the current model; interpret spikes with `issues_count` context.
