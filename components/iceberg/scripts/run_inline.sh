#!/usr/bin/env bash
# 执行临时 SQL（从标准输入读取），自动带上常用 SET 与 Catalog 定义
# 用法：
#   ./run_inline.sh <<'SQL'
#   SELECT count(*) FROM ice.demo.orders;
#   SQL
set -euo pipefail

{
  cat <<'PRE'
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'sql-client.display.max-column-width' = '200';
SET 'table.dml-sync' = 'true';

CREATE CATALOG ice WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///warehouse'
);
PRE
  cat
} > /tmp/iceberg-inline.sql

docker cp /tmp/iceberg-inline.sql iceberg-sql:/tmp/iceberg-inline.sql >/dev/null
docker exec -i iceberg-sql /opt/flink/bin/sql-client.sh embedded \
  -Dexecution.target=local \
  -f /tmp/iceberg-inline.sql
