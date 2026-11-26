-- 实验 04：并行度与 Slot
-- 并行度 4，但默认只有 1 个 TaskManager × 2 slot
-- 预期：作业无法调度，反复重启；扩容 TaskManager 后恢复 RUNNING

SET 'execution.runtime-mode' = 'streaming';
SET 'parallelism.default' = '4';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1000';
SET 'restart-strategy.fixed-delay.delay' = '3s';

CREATE TEMPORARY TABLE sensor_events (
  id INT,
  temperature DOUBLE,
  event_time TIMESTAMP(3),
  WATERMARK FOR event_time AS event_time - INTERVAL '2' SECOND
) WITH (
  'connector' = 'datagen',
  'rows-per-second' = '100',
  'fields.id.kind' = 'sequence',
  'fields.id.start' = '1',
  'fields.id.end' = '999999',
  'fields.temperature.min' = '60',
  'fields.temperature.max' = '95',
  'fields.event_time.kind' = 'random',
  'fields.event_time.max-past' = '10000'
);

CREATE TEMPORARY TABLE window_sink (
  window_start TIMESTAMP(3),
  window_end TIMESTAMP(3),
  event_count BIGINT,
  avg_temperature DOUBLE
) WITH (
  'connector' = 'print'
);

INSERT INTO window_sink
SELECT
  window_start,
  window_end,
  COUNT(*) AS event_count,
  AVG(temperature) AS avg_temperature
FROM TABLE(
  TUMBLE(TABLE sensor_events, DESCRIPTOR(event_time), INTERVAL '5' SECONDS)
)
GROUP BY window_start, window_end;
