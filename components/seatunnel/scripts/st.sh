#!/usr/bin/env bash
# 以 local 模式执行 jobs/ 下的作业
# 用法：./st.sh 01-fake-console.conf
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "用法: $0 <jobs/ 下的配置文件>"
  exit 1
fi

docker exec -i seatunnel-lab ./bin/seatunnel.sh \
  --config "/opt/seatunnel/jobs/$1" -m local
