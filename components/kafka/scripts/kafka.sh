#!/usr/bin/env bash
# 在 kafka-lab 容器内执行 Kafka 自带脚本
# 用法：./kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 --list
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "用法: $0 <kafka-xxx.sh> [args...]"
  exit 1
fi

script="$1"
shift

docker exec -i kafka-lab "/opt/kafka/bin/$script" "$@"
