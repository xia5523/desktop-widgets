#!/bin/bash
# 停止运行中的 DesktopWidgets
cd "$(dirname "$0")/.."
if pgrep -f "DesktopWidgets.app" >/dev/null; then
    pkill -f "DesktopWidgets.app"
    sleep 0.5
    echo "✓ 已停止"
else
    echo "当前没有运行"
fi
