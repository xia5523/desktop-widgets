# 桌面小挂件（desktop-widgets）

macOS 桌面古风圆形挂件：**罗盘**（五环旋转）与**太极**（玉环阴阳鱼）。
纯 Swift（SwiftUI 绘制 + AppKit 窗口/托盘），**不需要 Xcode.app**，只用命令行工具 swiftc 编译。

## 环境要求

- macOS 13+
- Command Line Tools（`xcode-select --install` 装的即可，无需完整 Xcode）

## 使用

```bash
./scripts/build.sh     # 编译到 build/DesktopWidgets.app
./scripts/start.sh     # 启动（源码有更新会自动重编译；已运行则提示）
./scripts/stop.sh      # 停止
./scripts/restart.sh   # 重启
```

启动后：无 Dock 图标，菜单栏出现挂件图标；各挂件悬浮于桌面。

## 交互

| 操作 | 效果 |
|---|---|
| 拖动挂件 | 移动位置（圆形外区域不响应） |
| 双击挂件 | 隐藏（从托盘菜单再显示） |
| 滚轮（罗盘上） | 临时加速/减速（不持久化） |
| 托盘菜单 | 每挂件独立子菜单：显示/隐藏、暂停/继续、样式、大小、还原默认、参数设置 |
| 托盘 · 退出 | 唯一退出入口 |

参数（转速、大小、样式）即时生效并持久化在 `defaults write com.xiaren.desktopwidgets` 域下。

## 源码结构（4 个文件，无第三方依赖）

| 文件 | 职责 |
|---|---|
| `src/Widget.swift` | `DesktopWidget` 基类：NSPanel 圆形悬浮窗生命周期、拖动/双击/滚轮交互、设置描述与 AppKit 自动设置面板、TimelineView+Canvas 逐帧驱动 |
| `src/CompassWidget.swift` | 罗盘：五环绘制（联珠/地支/回纹/祥云/团花）+ 三套配色 |
| `src/TaijiWidget.swift` | 太极：玉环镶珠 + 阴阳鱼（最简范例） |
| `src/main.swift` | 托盘菜单 + 挂件注册 + 应用入口 |

## 新增一个挂件

写一个 `DesktopWidget` 子类，实现 `id()`（持久化节点名，发布后别改）、`name()`、`defaultSize`、`designSize`、`settings`、`applySetting`（自己 `defaults.set` 持久化）、`tick(dt:)`、`draw(_ ctx: inout GraphicsContext)`，可选覆盖 `onWheel` / `initialOffset` / `addQuickItems` / `makeBadge`，然后在 `main.swift` 的数组里注册。设置面板、托盘子菜单全部自动生成。
