-- Refreshes qa_metrics.gamebench_daily_metrics using an idempotent upsert.
-- Intended to run at least daily UTC after ingest-gamebench completes.
-- Self-heal legacy environments where qa_metrics.gamebench_daily_metrics
-- may still exist as a VIEW from older setup scripts.
-- The latest day is consumed in Looker via is_latest_metric_date filters on this table.
DECLARE gamebench_daily_metrics_type STRING;
SET gamebench_daily_metrics_type = (
  SELECT table_type
  FROM `qa_metrics.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'gamebench_daily_metrics'
  LIMIT 1
);

IF gamebench_daily_metrics_type = 'VIEW' THEN
  EXECUTE IMMEDIATE 'DROP VIEW `qa_metrics.gamebench_daily_metrics`';
END IF;

CREATE TABLE IF NOT EXISTS `qa_metrics.gamebench_daily_metrics` (
  metric_date DATE,
  environment STRING,
  platform STRING,
  app_package STRING,
  app_version STRING,
  device_model STRING,
  device_manufacturer STRING,
  os_version STRING,
  gpu_model STRING,
  sessions INT64,
  median_fps FLOAT64,
  fps_stability_pct FLOAT64,
  fps_stability_index FLOAT64,
  cpu_avg_pct FLOAT64,
  cpu_max_pct FLOAT64,
  memory_avg_mb FLOAT64,
  memory_max_mb FLOAT64,
  current_avg_ma FLOAT64,
  _updated_at TIMESTAMP
)
PARTITION BY metric_date
CLUSTER BY environment, platform, app_version;

MERGE `qa_metrics.gamebench_daily_metrics` AS target
USING (
  SELECT
    DATE(time_pushed) AS metric_date,
    COALESCE(environment, 'unknown') AS environment,
    COALESCE(platform, 'unknown') AS platform,
    COALESCE(app_package, 'unknown') AS app_package,
    COALESCE(app_version, 'unknown') AS app_version,
    COALESCE(device_model, 'unknown') AS device_model,
    COALESCE(device_manufacturer, 'unknown') AS device_manufacturer,
    COALESCE(os_version, 'unknown') AS os_version,
    COALESCE(gpu_model, 'unknown') AS gpu_model,
    COUNT(*) AS sessions,
    AVG(median_fps) AS median_fps,
    AVG(fps_stability_pct) AS fps_stability_pct,
    AVG(fps_stability_index) AS fps_stability_index,
    AVG(cpu_avg_pct) AS cpu_avg_pct,
    MAX(cpu_max_pct) AS cpu_max_pct,
    AVG(memory_avg_mb) AS memory_avg_mb,
    MAX(memory_max_mb) AS memory_max_mb,
    AVG(current_avg_ma) AS current_avg_ma,
    CURRENT_TIMESTAMP() AS _updated_at
  FROM `qa_metrics.gamebench_sessions_latest`
  WHERE time_pushed IS NOT NULL
  GROUP BY
    metric_date,
    environment,
    platform,
    app_package,
    app_version,
    device_model,
    device_manufacturer,
    os_version,
    gpu_model
) AS source
ON target.metric_date = source.metric_date
  AND target.environment = source.environment
  AND target.platform = source.platform
  AND target.app_package = source.app_package
  AND target.app_version = source.app_version
  AND target.device_model = source.device_model
  AND target.device_manufacturer = source.device_manufacturer
  AND target.os_version = source.os_version
  AND target.gpu_model = source.gpu_model
WHEN MATCHED THEN
  UPDATE SET
    sessions = source.sessions,
    median_fps = source.median_fps,
    fps_stability_pct = source.fps_stability_pct,
    fps_stability_index = source.fps_stability_index,
    cpu_avg_pct = source.cpu_avg_pct,
    cpu_max_pct = source.cpu_max_pct,
    memory_avg_mb = source.memory_avg_mb,
    memory_max_mb = source.memory_max_mb,
    current_avg_ma = source.current_avg_ma,
    _updated_at = source._updated_at
WHEN NOT MATCHED THEN
  INSERT (
    metric_date,
    environment,
    platform,
    app_package,
    app_version,
    device_model,
    device_manufacturer,
    os_version,
    gpu_model,
    sessions,
    median_fps,
    fps_stability_pct,
    fps_stability_index,
    cpu_avg_pct,
    cpu_max_pct,
    memory_avg_mb,
    memory_max_mb,
    current_avg_ma,
    _updated_at
  )
  VALUES (
    source.metric_date,
    source.environment,
    source.platform,
    source.app_package,
    source.app_version,
    source.device_model,
    source.device_manufacturer,
    source.os_version,
    source.gpu_model,
    source.sessions,
    source.median_fps,
    source.fps_stability_pct,
    source.fps_stability_index,
    source.cpu_avg_pct,
    source.cpu_max_pct,
    source.memory_avg_mb,
    source.memory_max_mb,
    source.current_avg_ma,
    source._updated_at
  );
