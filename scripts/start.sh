#!/bin/bash
# 构建过期则先编译，然后启动（若已运行则提示）
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DesktopWidgets.app"
BIN="$APP/Contents/MacOS/DesktopWidgets"

if [ ! -d "$APP" ] || [ -n "$(find src scripts -newer "$BIN" -name '*.swift' -o -newer "$BIN" -name 'build.sh' 2>/dev/null)" ]; then
    ./scripts/build.sh
fi

if pgrep -f "DesktopWidgets.app" >/dev/null; then
    echo "已在运行（$(pgrep -f DesktopWidgets.app | tr '\n' ' ')），如需重启请用 restart.sh"
    exit 0
fi

nohup open "$APP" >/dev/null 2>&1 &
sleep 1
if pgrep -f "DesktopWidgets.app" >/dev/null; then
    echo "✓ 已启动：托盘出现「桌面小挂件」菜单"
else
    echo "✗ 启动失败，查看日志：~/Library/Logs/DiagnosticReports/"
    exit 1
fi
