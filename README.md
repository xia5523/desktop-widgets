# 桌面小挂件（desktop-widgets）

macOS 桌面挂件合集，古风为主：**罗盘**（五环旋转）、**太极**（玉环阴阳鱼）、
**灯笼**（红纱宫灯）、**时辰钟**（十二时辰真时钟）、**写轮眼**（三勾玉缓转），
外加全屏的**数字雨**（Matrix 雨幕）。
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

启动后：无 Dock 图标，菜单栏出现挂件图标；**所有挂件默认隐藏**，从托盘子菜单逐个打开。

## 交互

| 操作 | 效果 |
|---|---|
| 托盘 · 各挂件子菜单 | 显示/隐藏、暂停/继续、快捷项、还原默认、参数设置 |
| 拖动挂件 | 移动位置（圆形外区域不响应；数字雨整面响应不可拖） |
| 双击挂件 | 隐藏（从托盘菜单再显示）；数字雨双击 = 退出雨幕 |
| **ESC**（数字雨） | 退出全屏雨幕 |
| 滚轮（罗盘上） | 临时加速/减速（不持久化） |
| 托盘 · 退出 | 唯一退出入口 |

参数（转速、大小、样式、雨速、列距、尾长、配色、字符集、背景……）即时生效并持久化在
`defaults write com.xiaren.desktopwidgets` 域下。数字雨默认全黑沉浸背景，也可选半透明叠加桌面。

## 源码结构（8 个文件，无第三方依赖）

| 文件 | 职责 |
|---|---|
| `src/Widget.swift` | `DesktopWidget` 基类：NSPanel 悬浮窗生命周期、拖动/双击/滚轮/ESC 交互、设置描述与 AppKit 自动设置面板、TimelineView+Canvas 逐帧驱动 |
| `src/CompassWidget.swift` | 罗盘：五环绘制（联珠/地支/回纹/祥云/团花）+ 三套配色 |
| `src/TaijiWidget.swift` | 太极：玉环镶珠 + 阴阳鱼（最简范例） |
| `src/LanternWidget.swift` | 灯笼：烛光呼吸 + 挂点摆动 + 流苏滞后摆，灯面吉字可换 |
| `src/ClockWidget.swift` | 时辰钟：十二时辰真时钟（子在正上，昼夜针一天一圈，秒珠彗尾） |
| `src/SharinganWidget.swift` | 写轮眼：红瞳径向渐变 + 三勾玉 120° 分布缓转 |
| `src/MatrixRainWidget.swift` | 数字雨：全屏 Matrix 雨幕（像素直绘、20 步/秒、ESC 退出） |
| `src/main.swift` | 托盘菜单 + 挂件注册 + 应用入口 |

## 新增一个挂件

写一个 `DesktopWidget` 子类，实现 `id()`（持久化节点名，发布后别改）、`name()`、`defaultSize`、`designSize`、`settings`、`applySetting`（自己 `defaults.set` 持久化）、`tick(dt:)`、`draw(_ ctx: inout GraphicsContext)`，可选覆盖 `onWheel` / `initialOffset` / `addQuickItems` / `makeBadge` / `makePanel`，然后在 `main.swift` 的数组里注册。设置面板、托盘子菜单全部自动生成。全屏类挂件参考 `MatrixRainWidget`（`isFullScreenSurface` + 覆盖 `frame()` 像素直绘 + ESC 退出）。
