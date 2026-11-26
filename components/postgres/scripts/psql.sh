#!/usr/bin/env bash
# 在 pg-lab 容器内执行 psql
# 用法：./psql.sh -c "select version()"
#       ./psql.sh -f /sql/seed.sql
set -euo pipefail

if [ $# -eq 0 ]; then
  # 无参数时进入交互式终端
  exec docker exec -it pg-lab psql -U demo -d demo
fi

docker exec -i pg-lab psql -U demo -d demo "$@"
