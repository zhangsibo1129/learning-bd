#!/usr/bin/env bash
# 在 flink-jm 容器内执行 Flink 自带脚本
# 用法：./flink.sh flink list
#       ./flink.sh sql-client.sh -f /opt/flink/sql/02-window.sql
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "用法: $0 <flink|sql-client.sh|flink-daemon.sh> [args...]"
  exit 1
fi

cmd="$1"
shift

docker exec -i flink-jm "/opt/flink/bin/$cmd" "$@"
