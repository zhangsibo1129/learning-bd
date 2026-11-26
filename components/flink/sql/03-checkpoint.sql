-- 实验 03：Checkpoint 与故障恢复
-- 在窗口聚合基础上开启 checkpoint，杀掉 TaskManager 后观察作业自动恢复
-- 若状态被正确恢复，窗口计数会从断点继续，而不是从 0 重来

SET 'execution.runtime-mode' = 'streaming';
SET 'parallelism.default' = '1';
SET 'sql-client.execution.result-mode' = 'tableau';

SET 'execution.checkpointing.interval' = '5s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.dir' = 'file:///opt/flink/savepoints/checkpoints';
SET 'execution.checkpointing.min-pause' = '2s';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '100';
SET 'restart-strategy.fixed-delay.delay' = '3s';

CREATE TEMPORARY TABLE sensor_events (
  id INT,
  temperature DOUBLE,
  event_time TIMESTAMP(3),
  WATERMARK FOR event_time AS event_time - INTERVAL '2' SECOND
) WITH (
  'connector' = 'datagen',
  'rows-per-second' = '2',
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
