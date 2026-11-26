-- 实验 01：Catalog、数据库与第一张表
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'sql-client.display.max-column-width' = '200';
-- 内嵌模式下同步等待 INSERT 完成
SET 'table.dml-sync' = 'true';

CREATE CATALOG ice WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///warehouse'
);

CREATE DATABASE IF NOT EXISTS ice.demo;

CREATE TABLE IF NOT EXISTS ice.demo.orders (
  id       BIGINT,
  customer STRING,
  amount   DOUBLE,
  ts       TIMESTAMP(3)
);

INSERT INTO ice.demo.orders VALUES
  (1, 'alice', 12.50, TIMESTAMP '2026-11-01 10:00:00'),
  (2, 'bob',   30.00, TIMESTAMP '2026-11-01 11:00:00'),
  (3, 'carol',  7.80, TIMESTAMP '2026-11-02 09:30:00');

SELECT id, customer, amount, ts
FROM ice.demo.orders
ORDER BY id;
