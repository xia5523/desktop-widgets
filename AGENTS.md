# AGENTS.md — 桌面小挂件（desktop-widgets，Swift 版）

给在此仓库工作的 AI 助手 / 开发者的项目说明。改动代码前请先读完本文。

## 项目简介

macOS 桌面圆形小挂件集合。每个挂件是一个"类别"（罗盘、太极……），独立窗口、独立参数、
独立托盘子菜单。视觉走古风路线，全部矢量程序化绘制，**零第三方依赖**。

- 语言：Swift（SwiftUI 画布绘制 + AppKit 窗口/托盘）
- 平台：macOS 13+
- 入口：`src/main.swift`（`MainActor.assumeIsolated` 引导 `NSApplication.run()`）
- 本机**无 Xcode.app**，只有 Command Line Tools——所有构建走 `swiftc`

## 构建与运行

```bash
cd /Users/xiaren/Documents/claude_project/desktop-widgets
./scripts/build.sh     # swiftc -O → build/DesktopWidgets.app（含 Info.plist）
./scripts/start.sh     # 已运行则提示；源码更新自动重编译
./scripts/stop.sh
./scripts/restart.sh
```

保持"无构建工具、无依赖管理、无资源文件"的状态，不要引入 SPM/Xcode 工程/第三方库。

## 架构（4 个文件）

| 文件 | 职责 |
|---|---|
| `src/Widget.swift` | `DesktopWidget` 基类：无边框圆形 NSPanel 生命周期、`Setting` 设置项描述、UserDefaults 持久化读取、TimelineView+Canvas 每帧驱动、AppKit 自动设置面板 |
| `src/CompassWidget.swift` | 类别①"罗盘"：五环古风罗盘全部绘制逻辑 + 三套 Palette |
| `src/TaijiWidget.swift` | 类别②"太极"：玉环 + 阴阳鱼（最简实现参考） |
| `src/main.swift` | 宿主：注册类别、托盘分级菜单（TrayMenuBuilder 闭包式 target-action）、入口 |

### 新增一个挂件类别

1. 写一个 `DesktopWidget` 子类，实现：`id`（持久化节点名，取好就别改）、`name`、
   `trayIcon 同源的 makeBadge`、`defaultSize`、`designSize`、`settings`、
   `applySetting(key, value)`
2. `applySetting` 里**必须自己 `defaults.set(key, value)`** 持久化（基类只提供读取）
3. 动画实现 `tick(dt:)`（推进角度），绘制实现 `draw(_ ctx: inout GraphicsContext)`
4. 可选：覆盖 `addQuickItems` 加托盘快捷项、`onWheel` 加滚轮行为、`initialOffset` 控制首屏位置
5. 在 `main.swift` 的 `[DesktopWidget]` 数组里注册

动画模式统一：`TimelineView(.animation)` 每帧回调 → `frame(date, ctx, size)` 计算
`dt`（钳制 `0 < dt <= 0.1`，防休眠跳变）→ `tick(dt:)` 推进角度 → `draw()` 全量重画。
窗口不可见或 paused 时不 tick。**没有定时器对象**，暂停=不推进状态。

## 关键设计决策（改动前必读，全是踩过的坑）

1. **基类叫 `DesktopWidget`，不叫 `Widget`。** 单叫 `Widget` 会被 SourceKit/编译器
   混淆到 SwiftUI/WidgetKit 的 `Widget` 协议上。
2. **CommandLineTools 的 swiftc 编译不了 SwiftUI 属性包装宏**（`@State` 等）：
   报 `plugin for module 'SwiftUIMacros' not found`，插件 dylib 只随 Xcode 附带，
   系统和 SDK 里都没有。因此**设置面板用纯 AppKit**（NSSlider/NSPopUpButton/NSButton，
   见 `SettingsViewController`）；渲染路径（TimelineView/Canvas/徽章 View）不含宏，
   可以放心用 SwiftUI。以后装了 Xcode 才能重新考虑 SwiftUI 设置界面。
3. **SwiftUI `GraphicsContext` 没有 `saveGState/restoreGState`**（那是 CGContext 的）。
   等价物是**值拷贝**：`var c = ctx; c.rotate(...); c.stroke(...)`——副本共享绘制
   目标但变换独立，丢弃即"restore"。参见 `meander`/`petal`/太极阴阳鱼的写法。
4. **`GraphicsContext` 的变换方法（translateBy/scaleBy/rotateBy）是 `mutating`**：
   所有绘制函数签名一律 `_ ctx: inout GraphicsContext`，调用处 `&ctx`。
5. **SwiftUI 圆弧角度系**：0° = 3 点钟方向，y 轴向下，角度正方向 = 屏幕顺时针。
   左半圆（竖直直径弦）：`addArc(center:.zero, radius:R, startAngle:.degrees(270),
   endAngle:.degrees(90), clockwise:false)` + `closeSubpath()`。与 AWT/JavaFX 规矩都不同，
   迁移代码时务必重算。
   - **`clockwise:` 参数名是反的**：它按传统数学系（y 向上）命名，屏幕上看
     `clockwise: false` 才是顺时针（角度递增）、`clockwise: true` 是逆时针。
     祥云的拱形（180°→360° 向上拱）必须用 `clockwise: false`——用 `true` 会朝下翻，
     离屏渲染验证过（见 /tmp/dw_snap harness 思路：ImageRenderer→PNG→看图）。
6. **MainActor**：`ImageRenderer`（托盘徽章）是 MainActor 隔离的 → `makeBadge()` 标了
   `@MainActor`，`AppDelegate` 整类 `@MainActor`；main.swift 顶层代码无法标注，用
   `MainActor.assumeIsolated { ... }` 包住引导段（进程入口本来就在主线程）。
7. **窗口配置**：`NSPanel` + `[.borderless, .nonactivatingPanel]`，`backgroundColor =
   .clear`、`isOpaque = false`、`level = .floating`、`canJoinAllSpaces +
   fullScreenAuxiliary`、`hidesOnDeactivate = false`。SwiftUI 透明合成没有 Java 版
   那个"半透明窗口周期性闪白"的坑，不需要 opaque 模式兜底。
8. **无边框窗口的拖动自己实现**（`WidgetHostingView` mouseDown/mouseDragged 用
   `NSEvent.mouseLocation` 差值），配圆形命中检测兜底：圆外不响应任何鼠标事件。
9. **双击 = 隐藏该挂件，不是退出**。退出只能走托盘菜单"退出"（唯一 terminate 调用点
   在 main.swift）。
10. **托盘 target-action 必须保活**：NSMenuItem.target 是弱引用，closure 统一托管在
    `TrayMenuBuilder.actions` 里；**builder 本身必须存成 AppDelegate 的属性**——
    曾把它当局部变量，函数一返回 builder 连同全部 ActionItem 被释放，菜单点得开
    但每一项都没反应（症状：托盘"点不动了"）。设置面板的 `RowTarget` 同理由
    ViewController 持有。菜单回调里改标题用 `mutableItem`。窗口缓存复用的
    `settingsWindow` 要 `isReleasedWhenClosed = false`，否则关闭后再开会崩。
11. **Swift 代码全部在主线程**（AppKit 惯例），动画/绘制状态不加锁。

## 画面规范

- 所有挂件按**设计坐标**绘制（罗盘 360、太极 240），`frame()` 里统一平移到中心 +
  `scale(size/designSize)`，窗口大小变化时画面等比缩放。
- 配色收进 `Palette`（`CompassWidget.TANG/BRONZE/INKP`），禁止散落魔法色值；
  新增样式 = 加一个 Palette + 挂进数组 + 设置项 options 同步。
- 罗盘环结构（外→内）：联珠纹 → 地支十二字 → 回纹 → 祥云 → 团花，每环独立转速
  （负值 = 反转），绘制函数与环一一对应，别把多环画进一个函数。

## 设置与持久化

- 设置项用 `Setting.num/choice/bool` 描述，`SettingsViewController` 据此自动生成
  滑杆/下拉/勾选面板，改动即时生效——新增设置**不需要**碰 UI 代码。面板自带
  "还原默认"（重放全部 def 并回读刷新控件）。
- 存储走 `UserDefaults`，key = `widgets.<id>.<key>`（`speed.*`、`size`、`style`）。
  `id` 一旦发布就不要改，否则用户已存的参数会失联。
- `.app` 包内 `Info.plist` 的 `LSUIElement=true` 保证无 Dock 图标；标识符
  `com.xiaren.desktopwidgets` 就是 defaults 域名。

## 交互约定

- 拖动 = 移动；圆外不响应
- 双击 = 隐藏/显示切换（显示走托盘）
- 滚轮 = 临时调速（`wheelFactor` 运行时系数，不持久化，只作用于罗盘）
- 托盘 = 每类别一个顶级子菜单：显示/隐藏、暂停/继续、快捷项、参数设置…

## 历史包袱

本项目前身是 Java/Swing + JavaFX 版（已整体备份到兄弟目录
`../desktop-widgets-java-backup/`），曾因 macOS 半透明窗口闪白、JavaFX 弧参数体系
踩坑而重写。参考它时注意两个版本的弧角度规矩不同（见上文第 5 条）。
