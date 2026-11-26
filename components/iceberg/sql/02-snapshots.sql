-- 实验 02：快照与变更历史
-- 前提：已执行 01-catalog.sql
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'sql-client.display.max-column-width' = '200';
SET 'table.dml-sync' = 'true';

CREATE CATALOG ice WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///warehouse'
);

INSERT INTO ice.demo.orders VALUES
  (4, 'dave', 99.90, TIMESTAMP '2026-11-03 08:00:00');

SELECT snapshot_id, committed_at, operation
FROM ice.demo.`orders$snapshots`
ORDER BY committed_at;
