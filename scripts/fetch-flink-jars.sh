#!/usr/bin/env bash
# 下载 Flink 1.20 运行 Iceberg / Kafka 所需 jar，已存在则跳过
set -euo pipefail

MIRROR="${MAVEN_MIRROR:-https://maven.aliyun.com/repository/public}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/docker/flink/lib"
mkdir -p "$DIR"

urls=(
  "$MIRROR/org/apache/iceberg/iceberg-flink-runtime-1.20/1.9.1/iceberg-flink-runtime-1.20-1.9.1.jar"
  "$MIRROR/org/apache/iceberg/iceberg-aws-bundle/1.9.1/iceberg-aws-bundle-1.9.1.jar"
  "$MIRROR/org/apache/flink/flink-sql-connector-kafka/3.3.0-1.20/flink-sql-connector-kafka-3.3.0-1.20.jar"
  "$MIRROR/org/postgresql/postgresql/42.7.12/postgresql-42.7.12.jar"
  # Iceberg JDBC Catalog 初始化依赖 Hadoop Configuration
  "$MIRROR/org/apache/hadoop/hadoop-client-api/3.3.6/hadoop-client-api-3.3.6.jar"
  "$MIRROR/org/apache/hadoop/hadoop-client-runtime/3.3.6/hadoop-client-runtime-3.3.6.jar"
)

for url in "${urls[@]}"; do
  target="$DIR/$(basename "$url")"
  if [ -f "$target" ]; then
    echo "skip  $(basename "$url")"
    continue
  fi
  echo "fetch $(basename "$url")"
  curl -fL --retry 3 --connect-timeout 15 -o "$target.part" "$url"
  mv "$target.part" "$target"
done

echo "done -> $DIR"
