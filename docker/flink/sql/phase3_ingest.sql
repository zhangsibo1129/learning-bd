-- 阶段 3：Kafka 设备事件 -> 清洗 -> Iceberg（RustFS 存储 + PostgreSQL JDBC Catalog）
-- 以批量作业方式运行：读取 Kafka 当前全部消息，作业结束即提交 Iceberg 快照

SET 'execution.runtime-mode' = 'batch';
SET 'parallelism.default' = '2';
-- 内嵌模式下同步等待 INSERT 完成，避免客户端退出导致作业取消
SET 'table.dml-sync' = 'true';
SET 'sql-client.execution.result-mode' = 'tableau';
-- 放宽表格列宽，避免指标字符串被截断
SET 'sql-client.display.max-column-width' = '200';

CREATE CATALOG iceberg_catalog WITH (
  'type' = 'iceberg',
  -- Flink 侧不识别 catalog-type=jdbc，直接指定 catalog-impl 走 JDBC Catalog
  'catalog-impl' = 'org.apache.iceberg.jdbc.JdbcCatalog',
  'uri' = 'jdbc:postgresql://postgres:5432/ontology_demo',
  'jdbc.user' = 'demo',
  'jdbc.password' = 'demo123',
  'warehouse' = 's3://ontology-demo/warehouse',
  'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint' = 'http://rustfs:9000',
  's3.path-style-access' = 'true',
  's3.access-key-id' = 'rustfsadmin',
  's3.secret-access-key' = 'rustfsadmin',
  'client.region' = 'us-east-1'
);

CREATE DATABASE IF NOT EXISTS iceberg_catalog.lakehouse;

CREATE TABLE IF NOT EXISTS iceberg_catalog.lakehouse.equipment_cleaned (
  id STRING,
  name STRING,
  `model` STRING,
  factory_id STRING,
  status STRING,
  temperature DOUBLE,
  event_time TIMESTAMP(3),
  synced_at STRING,
  PRIMARY KEY (id) NOT ENFORCED
)
WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true'
);

CREATE TEMPORARY TABLE equipment_events (
  id STRING,
  name STRING,
  `model` STRING,
  factory_id STRING,
  status STRING,
  temperature DOUBLE,
  created_at STRING,
  synced_at STRING,
  event_time AS TO_TIMESTAMP(synced_at)
) WITH (
  'connector' = 'kafka',
  'topic' = 'equipment-events',
  'properties.bootstrap.servers' = 'kafka:9094',
  'properties.group.id' = 'flink-phase3',
  'scan.startup.mode' = 'earliest-offset',
  'scan.bounded.mode' = 'latest-offset',
  'format' = 'json',
  'json.ignore-parse-errors' = 'true'
);

INSERT INTO iceberg_catalog.lakehouse.equipment_cleaned
SELECT id, name, `model`, factory_id, status, temperature, event_time, synced_at
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY synced_at DESC) AS rn
  FROM equipment_events
  WHERE id IS NOT NULL
    AND temperature IS NOT NULL
    AND temperature > 0
    AND temperature <= 85
) AS dedup
WHERE rn = 1;

-- 验收指标（Notebook 据此断言）
SELECT CONCAT('metric total=', CAST(COUNT(*) AS STRING)) AS metric
FROM iceberg_catalog.lakehouse.equipment_cleaned;

SELECT CONCAT('metric status=', status, '=', CAST(COUNT(*) AS STRING)) AS metric
FROM iceberg_catalog.lakehouse.equipment_cleaned
GROUP BY status;

SELECT CONCAT('metric sample=', id, '|', status, '|', CAST(temperature AS STRING)) AS metric
FROM iceberg_catalog.lakehouse.equipment_cleaned
ORDER BY id
LIMIT 3;
