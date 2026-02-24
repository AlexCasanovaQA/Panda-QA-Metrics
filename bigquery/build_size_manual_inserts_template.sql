-- Template: manual weekly inserts for qa_metrics.build_size_manual
--
-- Expected columns:
--   metric_date DATE,
--   platform STRING,
--   environment STRING,
--   build_version STRING,
--   build_size_mb FLOAT64
--
-- Optional column in newer setups:
--   _updated_at TIMESTAMP
--
-- Recommended cadence:
--   - Insert/update at least one row per platform/environment each week.
--   - Keep metric_date in UTC.

INSERT INTO `qa_metrics.build_size_manual`
  (metric_date, platform, environment, build_version, build_size_mb)
VALUES
  (DATE '2026-02-09', 'Android', 'prod', '1.42.0', 812.40),
  (DATE '2026-02-09', 'iOS',     'prod', '1.42.0', 745.10),
  (DATE '2026-02-16', 'Android', 'prod', '1.43.0', 818.20),
  (DATE '2026-02-16', 'iOS',     'prod', '1.43.0', 751.60);

-- Optional upsert pattern (useful if you may re-run the same week/version):
-- MERGE `qa_metrics.build_size_manual` t
-- USING (
--   SELECT DATE '2026-02-16' AS metric_date, 'Android' AS platform, 'prod' AS environment, '1.43.0' AS build_version, 818.20 AS build_size_mb
-- ) s
-- ON  t.metric_date = s.metric_date
-- AND t.platform = s.platform
-- AND t.environment = s.environment
-- WHEN MATCHED THEN UPDATE SET
--   build_version = s.build_version,
--   build_size_mb = s.build_size_mb
-- WHEN NOT MATCHED THEN INSERT
--   (metric_date, platform, environment, build_version, build_size_mb)
-- VALUES
--   (s.metric_date, s.platform, s.environment, s.build_version, s.build_size_mb);
