-- 实验 05：分区表
-- Flink DDL 支持按物理列做 identity 分区：PARTITIONED BY (dt)
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'sql-client.display.max-column-width' = '200';
SET 'table.dml-sync' = 'true';

CREATE CATALOG ice WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///warehouse'
);

CREATE TABLE IF NOT EXISTS ice.demo.events (
  id      BIGINT,
  dt      STRING,
  ts      TIMESTAMP(3),
  payload STRING
) PARTITIONED BY (dt);

INSERT INTO ice.demo.events VALUES
  (1, '2026-11-01', TIMESTAMP '2026-11-01 10:00:00', 'a'),
  (2, '2026-11-02', TIMESTAMP '2026-11-02 11:00:00', 'b'),
  (3, '2026-11-02', TIMESTAMP '2026-11-02 12:00:00', 'c'),
  (4, '2026-11-03', TIMESTAMP '2026-11-03 09:00:00', 'd');

SELECT dt, count(*) AS cnt
FROM ice.demo.events
GROUP BY dt
ORDER BY dt;

EXPLAIN SELECT * FROM ice.demo.events WHERE dt = '2026-11-02';
