#!/bin/bash
# 重启：先停再起（会顺带按需重编译）
set -e
cd "$(dirname "$0")/.."
./scripts/stop.sh || true
./scripts/start.sh
