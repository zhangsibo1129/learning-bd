-- 实验 02：Watermark 与滚动窗口
-- 数据源：datagen 每秒 2 条，事件时间随机落在过去 10 秒内
-- 目标：观察窗口只有在 watermark 越过窗口结束时间后才输出

SET 'execution.runtime-mode' = 'streaming';
SET 'parallelism.default' = '1';
SET 'sql-client.execution.result-mode' = 'tableau';

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
