-- 实验 04：Schema 演进
-- 前提：已执行 01、02
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'sql-client.display.max-column-width' = '200';
SET 'table.dml-sync' = 'true';

CREATE CATALOG ice WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///warehouse'
);

ALTER TABLE ice.demo.orders ADD (note STRING);

INSERT INTO ice.demo.orders VALUES
  (5, 'erin', 50.00, TIMESTAMP '2026-11-04 12:00:00', 'vip');

-- 老数据在新列上自动为 NULL，不需要回填
SELECT id, customer, note FROM ice.demo.orders ORDER BY id;
