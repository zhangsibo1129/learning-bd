#!/usr/bin/env bash
# 以 embedded 模式执行 sql/ 下的作业
# 用法：./sql.sh 01-catalog.sql
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "用法: $0 <sql/ 下的文件名>"
  exit 1
fi

file="$1"
docker exec -i iceberg-sql /opt/flink/bin/sql-client.sh embedded \
  -Dexecution.target=local \
  -f "/opt/flink/sql/$file"
