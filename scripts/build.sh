#!/bin/bash
# 编译 DesktopWidgets.app（纯 swiftc，无需 Xcode.app）
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DesktopWidgets.app"
MACOS="$APP/Contents/MacOS"

mkdir -p "$MACOS" "build/.run"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>桌面小挂件</string>
    <key>CFBundleDisplayName</key>       <string>桌面小挂件</string>
    <key>CFBundleIdentifier</key>        <string>com.xiaren.desktopwidgets</string>
    <key>CFBundleExecutable</key>        <string>DesktopWidgets</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
EOF

echo "▸ swiftc -O 编译中…"
swiftc -O -o "$MACOS/DesktopWidgets" src/*.swift

# App 图标 = 罗盘徽章（用 sips 从无到有太绕，这里直接留空用系统默认）
echo "✓ 构建完成：$APP"
