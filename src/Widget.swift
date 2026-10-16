import SwiftUI
import AppKit

// MARK: - 设置项描述

struct Setting {
    enum Kind {
        case num(Int, Int)      // min, max
        case choice([String])
        case bool
    }
    let key: String
    let label: String
    let kind: Kind
    let def: String

    static func num(_ key: String, _ label: String, _ min: Int, _ max: Int, _ def: Int) -> Setting {
        Setting(key: key, label: label, kind: .num(min, max), def: String(def))
    }
    static func choice(_ key: String, _ label: String, _ options: [String], _ def: String) -> Setting {
        Setting(key: key, label: label, kind: .choice(options), def: def)
    }
    static func bool(_ key: String, _ label: String, _ def: Bool) -> Setting {
        Setting(key: key, label: label, kind: .bool, def: String(def))
    }
    var intDef: Int { Int(def) ?? 0 }
    var boolDef: Bool { def == "true" }
}

// MARK: - 挂件基类

/// 无边框圆形悬浮窗：NSPanel(borderless + nonactivating) + SwiftUI Canvas 逐帧绘制。
/// 子类只关心：画什么（draw）、每拍动什么（tick）、有哪些设置项。
class DesktopWidget {
    let defaults = UserDefaults.standard

    var panel: NSPanel?
    var paused = false
    var settingsWindow: NSWindow?
    private var lastDate = Date.distantPast

    // ---------- 子类覆盖 ----------
    var id: String { "" }
    var name: String { "" }
    var defaultSize: Int { 240 }
    var designSize: CGFloat { 240 }
    var settings: [Setting] { [] }
    /// 应用并持久化一个设置项（必须自己 defaults.set）
    func applySetting(_ key: String, _ value: String) {}
    /// 动画一拍：推进角度。dt 为秒；不可见/暂停时不会被调用
    func tick(dt: TimeInterval) {}
    /// 整帧绘制。坐标系已位于设计空间中心（原点=圆心，单位=设计坐标）
    func draw(_ ctx: inout GraphicsContext) {}
    /// 滚轮钩子（units < 0 = 上滚加速）
    func onWheel(_ units: Int) {}
    /// 首屏位置偏移（基于主屏中心）
    func initialOffset() -> CGPoint { .zero }
    /// 托盘徽章（ImageRenderer 是 MainActor 隔离的，托盘构建也在主线程）
    @MainActor func makeBadge() -> NSImage { NSImage(size: NSSize(width: 64, height: 64)) }
    /// 托盘快捷项，可覆盖
    func addQuickItems(_ mb: TrayMenuBuilder, _ sub: NSMenu) {}

    // ---------- 持久化（UserDefaults，key 前缀 widgets.<id>）----------

    func prefKey(_ k: String) -> String { "widgets.\(id).\(k)" }
    func intVal(_ k: String, _ def: Int) -> Int {
        guard let s = defaults.string(forKey: prefKey(k)), let v = Int(s) else { return def }
        return v
    }
    func strVal(_ k: String, _ def: String) -> String {
        defaults.string(forKey: prefKey(k)) ?? def
    }
    func boolVal(_ k: String, _ def: Bool) -> Bool {
        strVal(k, String(def)) == "true"
    }

    // ---------- 窗口生命周期 ----------

    func show() {
        if panel == nil {
            let size = intVal("size", defaultSize)
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.hidesOnDeactivate = false
            let hv = WidgetHostingView(rootView: SurfaceView(widget: self))
            hv.autoresizingMask = [.width, .height]
            hv.widget = self
            p.contentView = hv
            panel = p
            initialLocation()
        }
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
    var visible: Bool { panel?.isVisible ?? false }
    func toggleVisible() { if visible { hide() } else { show() } }

    /// 首屏位置：主屏居中 + 子类偏移
    func initialLocation() {
        guard let screen = NSScreen.main, let p = panel else { return }
        let size = intVal("size", defaultSize)
        let vis = screen.visibleFrame
        p.setFrameOrigin(NSPoint(x: vis.midX - CGFloat(size) / 2 + initialOffset().x,
                                 y: vis.midY - CGFloat(size) / 2 + initialOffset().y))
    }

    /// 改尺寸（applySetting 的 "size" 分支调用），保持窗口中心不动
    func resize(_ size: Int) {
        guard let p = panel else { return }
        var f = p.frame
        f.origin.x += (f.width - CGFloat(size)) / 2
        f.origin.y += (f.height - CGFloat(size)) / 2
        f.size = NSSize(width: size, height: size)
        p.setFrame(f, display: true)
    }

    /// 全部设置重放为默认值
    func resetToDefaults() {
        for s in settings { applySetting(s.key, s.def) }
    }

    /// 打开参数设置窗口（自动生成的滑杆/下拉/勾选，含还原默认）
    @MainActor func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: SettingsViewController(widget: self))
            w.title = "\(name) · 参数"
            w.styleMask.insert(.closable)        // 默认 .titled 无关闭按钮
            w.isReleasedWhenClosed = false       // 窗口缓存复用，关闭仅 orderOut
            w.appearance = NSAppearance(named: .vibrantDark)
            settingsWindow = w
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // ---------- 每帧驱动（Canvas 回调）----------

    func frame(_ date: Date, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let dt = date.timeIntervalSince(lastDate)
        lastDate = date
        if dt > 0 && dt <= 0.1 && visible && !paused { tick(dt: dt) }
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        let s = size.width / designSize
        ctx.scaleBy(x: s, y: s)
        draw(&ctx)
    }
}

// MARK: - 画布

struct SurfaceView: View {
    let widget: DesktopWidget
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                widget.frame(timeline.date, &ctx, size)
            }
        }
    }
}

// MARK: - 承载视图：拖动移动 / 双击隐藏 / 滚轮钩子 / 圆形命中

final class WidgetHostingView: NSHostingView<SurfaceView> {
    weak var widget: DesktopWidget?
    private var dragMouse: NSPoint?
    private var dragWin: NSPoint?

    override func mouseDown(with event: NSEvent) {
        let b = bounds
        let p = convert(event.locationInWindow, from: nil)
        let dx = p.x - b.midX, dy = p.y - b.midY
        let r = min(b.width, b.height) / 2
        if dx * dx + dy * dy > r * r { return }              // 圆外不响应
        if event.clickCount >= 2 { widget?.hide(); return }  // 双击 = 隐藏（退出走托盘）
        dragMouse = NSEvent.mouseLocation                     // 其余 = 拖动移动
        dragWin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let d = dragMouse, let w = dragWin, let win = window else { return }
        let cur = NSEvent.mouseLocation
        win.setFrameOrigin(NSPoint(x: w.x + cur.x - d.x, y: w.y + cur.y - d.y))
    }

    override func mouseUp(with event: NSEvent) {
        dragMouse = nil
        dragWin = nil
    }

    override func scrollWheel(with event: NSEvent) {
        widget?.onWheel(event.deltaY < 0 ? -1 : 1)
    }
}

// MARK: - 设置面板（AppKit 自动生成，暗色）
// 不用 SwiftUI 做设置界面：CommandLineTools 的 swiftc 缺 SwiftUIMacros 插件，
// 编译不了 @State 等属性包装宏；渲染路径（Canvas/TimelineView）不受影响。

/// 闭包式 target-action，保住 target 引用
private final class RowTarget: NSObject {
    let change: () -> Void
    init(_ change: @escaping () -> Void) { self.change = change }
    @objc func fire() { change() }
}

/// 每行记录控件引用，供"还原默认"后整表回读刷新
private final class RowBox {
    let setting: Setting
    weak var slider: NSSlider?
    weak var popup: NSPopUpButton?
    weak var check: NSButton?
    weak var valueLabel: NSTextField?
    var options: [String] = []

    init(_ s: Setting) { setting = s }
}

@MainActor
final class SettingsViewController: NSViewController {
    let widget: DesktopWidget
    private var rows: [RowBox] = []
    private var targets: [RowTarget] = []

    init(widget: DesktopWidget) {
        self.widget = widget
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("不支持 NSCoder") }

    override func loadView() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 14, right: 20)
        stack.spacing = 12

        for s in widget.settings { stack.addArrangedSubview(makeRow(s)) }

        // 底部：还原默认
        let reset = NSButton(title: "还原默认", target: self, action: #selector(resetAll))
        reset.bezelStyle = .rounded
        let pad = NSView()
        pad.setContentHuggingPriority(.init(1), for: .horizontal)
        let buttons = NSStackView(views: [pad, reset])
        buttons.orientation = .horizontal
        stack.addArrangedSubview(buttons)

        view = stack
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = view.fittingSize
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 13)
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    private func makeRow(_ s: Setting) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        let box = RowBox(s)
        rows.append(box)

        let l = label(s.label)
        l.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(l)

        switch s.kind {
        case .num(let minV, let maxV):
            let slider = NSSlider(value: Double(widget.intVal(s.key, s.intDef)),
                                  minValue: Double(minV), maxValue: Double(maxV),
                                  target: nil, action: nil)
            slider.isContinuous = true
            let val = NSTextField(labelWithString: String(widget.intVal(s.key, s.intDef)))
            val.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            val.textColor = .secondaryLabelColor
            val.widthAnchor.constraint(equalToConstant: 36).isActive = true
            val.alignment = .right
            let t = RowTarget { [weak self, weak slider, weak val] in
                guard let self, let slider else { return }
                self.widget.applySetting(s.key, String(Int(slider.doubleValue)))
                val?.stringValue = String(Int(slider.doubleValue))
            }
            slider.target = t
            slider.action = #selector(RowTarget.fire)
            targets.append(t)
            slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
            row.addArrangedSubview(slider)
            row.addArrangedSubview(val)
            box.slider = slider
            box.valueLabel = val

        case .choice(let options):
            let popup = NSPopUpButton()
            popup.addItems(withTitles: options)
            popup.selectItem(withTitle: widget.strVal(s.key, s.def))
            let t = RowTarget { [weak self, weak popup] in
                guard let self, let popup else { return }
                let idx = popup.indexOfSelectedItem
                self.widget.applySetting(s.key, options[idx])
            }
            popup.target = t
            popup.action = #selector(RowTarget.fire)
            targets.append(t)
            popup.widthAnchor.constraint(equalToConstant: 240).isActive = true
            row.addArrangedSubview(popup)
            box.popup = popup
            box.options = options

        case .bool:
            let check = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            check.state = widget.boolVal(s.key, s.boolDef) ? .on : .off
            let t = RowTarget { [weak self, weak check] in
                guard let self, let check else { return }
                self.widget.applySetting(s.key, check.state == .on ? "true" : "false")
            }
            check.target = t
            check.action = #selector(RowTarget.fire)
            targets.append(t)
            row.addArrangedSubview(check)
            box.check = check
        }
        return row
    }

    @objc private func resetAll() {
        widget.resetToDefaults()
        for box in rows {
            let s = box.setting
            if let sl = box.slider {
                sl.doubleValue = Double(widget.intVal(s.key, s.intDef))
                box.valueLabel?.stringValue = String(Int(sl.doubleValue))
            }
            if let p = box.popup {
                p.selectItem(withTitle: widget.strVal(s.key, s.def))
            }
            if let c = box.check {
                c.state = widget.boolVal(s.key, s.boolDef) ? .on : .off
            }
        }
    }
}
