import SwiftUI
import AppKit

// MARK: - 挂件类别六：黑客帝国数字雨（全屏）

/// 全屏 Matrix 数字雨：片假名/数字雨幕铺满主屏，ESC 或双击退出，托盘调参数。
/// 与圆形挂件不同点（对应基类的三个钩子）：
/// - `isFullScreenSurface`：矩形全响应、不拖动、面板可成为 key 窗收键盘
/// - `showAtLaunch = false`：启动不自动铺屏，走托盘"显示"进入雨幕
/// - 覆盖 `frame()`：像素坐标直绘（左上原点），不做中心平移/等比缩放
class MatrixRainWidget: DesktopWidget {
    struct Col {
        var head: Double      // 雨头行号（0 = 顶行，可为负 = 屏上方待落）
        var f: Double         // 相对速度系数（乘全局 speed）
        var chars: [Character]
    }

    /// 配色：雨头近白 → 雨身主色，配合每帧 opacity 做尾迹渐隐
    static let STYLES: [String: (UInt32, UInt32)] = [
        "经典绿": (0xDBFFE2, 0x1FD65F),
        "赛博青": (0xDDFEFF, 0x17C6DC),
        "琥珀金": (0xFFF2CB, 0xE0A31F),
        "冰蓝":   (0xE7F4FF, 0x4D91EC),
        "幽紫":   (0xF8E2FF, 0xA757E9),
    ]
    static let KATA: [Character] = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンヴガギグゲゴザジズゼゾダヂヅデド")
    static let DIGI: [Character] = Array("0123456789ABCDEF+-*/=<>()[]{}#$%&@!?")
    static let CHARSETS: [String: [Character]] = ["片假名": KATA, "数字": DIGI, "混合": KATA + DIGI]

    // 参数（loadConfig 回读）
    var speed = 14          // 雨速：基准行/秒
    var colWidth = 26       // 列距 px（越小越密）
    var trail = 18          // 尾长（字数）
    var styleName = "经典绿"
    var charsetName = "片假名"
    var bgName = "全黑"

    // 布局（ensureLayout 按需重建）
    var viewSize: CGSize = .zero
    var layoutKey = ""
    var cellW: CGFloat = 26, cellH: CGFloat = 39
    var font = Font.system(size: 30, weight: .bold, design: .monospaced)
    var rows = 0
    var columns: [Col] = []

    override init() {
        super.init()
        loadConfig()
    }

    override var id: String { "matrix" }
    override var name: String { "数字雨" }
    override var defaultSize: Int { 400 }        // 面板创建尺寸，随后 initialLocation 铺满整屏
    override var designSize: CGFloat { 360 }     // 像素直绘，不走设计坐标
    override var isFullScreenSurface: Bool { true }
    override var frameInterval: Double? { 1.0 / 20.0 }   // 20 步/秒：雨幕原速，也省电

    func loadConfig() {
        speed = intVal("speed", 14)
        colWidth = intVal("density", 26)
        trail = intVal("trail", 18)
        styleName = strVal("style", "经典绿")
        charsetName = strVal("charset", "片假名")
        bgName = strVal("bg", "全黑")
    }

    override var settings: [Setting] {
        [
            .num("speed", "雨速（行/秒）", 3, 60, 14),
            .num("density", "列距（px，越小越密）", 14, 56, 26),
            .num("trail", "尾长（字数）", 5, 40, 18),
            .choice("style", "配色", ["经典绿", "赛博青", "琥珀金", "冰蓝", "幽紫"], "经典绿"),
            .choice("charset", "字符集", ["片假名", "数字", "混合"], "片假名"),
            .choice("bg", "背景", ["全黑", "深黑", "透明"], "全黑"),
        ]
    }

    override func applySetting(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefKey(key))
        loadConfig()   // 布局参数变了 ensureLayout 会按 key 失效重建
    }

    override func tick(dt: TimeInterval) {
        guard !columns.isEmpty else { return }
        let charset = Self.CHARSETS[charsetName] ?? Self.KATA
        for i in columns.indices {
            let prevRow = Int(columns[i].head)
            columns[i].head += Double(speed) * columns[i].f * dt
            let row = Int(columns[i].head)
            if row != prevRow {   // 雨头扫过的行刷新字形（电影里字形随机翻变）
                let lo = max(prevRow, 0), hi = min(row, columns[i].chars.count - 1)
                if lo <= hi {
                    for r in lo...hi { columns[i].chars[r] = charset.randomElement()! }
                }
            }
            if columns[i].head - Double(trail) > Double(rows) {   // 出屏 → 顶部随机重生
                columns[i].head = Double.random(in: -30 ... -3)
                columns[i].f = Double.random(in: 0.35 ... 1.75)
            }
        }
        // 尾迹闪烁：每拍随机改几处字
        for _ in 0..<(columns.count / 6 + 1) {
            let i = Int.random(in: 0..<columns.count)
            let head = Int(columns[i].head)
            let lo = max(0, head - trail), hi = min(head, columns[i].chars.count - 1)
            if lo <= hi {
                columns[i].chars[Int.random(in: lo...hi)] = charset.randomElement()!
            }
        }
    }

    // ---------- 绘制（像素坐标，左上原点）----------

    /// 尺寸/列距/尾长/字符集任一变化才重建列阵
    func ensureLayout(_ size: CGSize) {
        let key = "\(Int(size.width))x\(Int(size.height))|\(colWidth)|\(trail)|\(charsetName)"
        if key == layoutKey { return }
        layoutKey = key
        viewSize = size
        cellW = CGFloat(colWidth)
        cellH = cellW * 1.5
        font = Font.system(size: cellW * 1.18, weight: .bold, design: .monospaced)
        rows = Int(size.height / cellH) + 2
        let charset = Self.CHARSETS[charsetName] ?? Self.KATA
        let n = Int(size.width / cellW) + 1
        columns = (0..<n).map { _ in
            Col(head: Double.random(in: -40 ... Double(rows)),
                f: Double.random(in: 0.35 ... 1.75),
                chars: (0..<(rows + 8)).map { _ in charset.randomElement()! })
        }
    }

    override func frame(_ date: Date, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let dt = date.timeIntervalSince(lastDate)
        lastDate = date
        if dt > 0 && dt <= 0.1 && visible && !paused { tick(dt: dt) }
        viewSize = size
        draw(&ctx)   // 不做中心平移/缩放，直接像素坐标
    }

    override func draw(_ ctx: inout GraphicsContext) {
        guard viewSize.width > 8, viewSize.height > 8 else { return }
        ensureLayout(viewSize)

        // 背景（全黑 = 沉浸式；透明 = 叠在桌面上）
        let bgAlpha: Double = bgName == "全黑" ? 1.0 : (bgName == "深黑" ? 0.82 : 0)
        if bgAlpha > 0.01 {
            ctx.fill(Path(CGRect(origin: .zero, size: viewSize)), with: .color(.black.opacity(bgAlpha)))
        }

        let (headHex, bodyHex) = Self.STYLES[styleName] ?? (0xDBFFE2, 0x1FD65F)
        let headCol = rgb(headHex), bodyCol = rgb(bodyHex)
        // 字形缓存：每帧惰性 resolve（字符集就几十个），同一字形可重复 draw
        var headCache: [Character: GraphicsContext.ResolvedText] = [:]
        var bodyCache: [Character: GraphicsContext.ResolvedText] = [:]

        let trailF = Double(trail)
        for (i, col) in columns.enumerated() {
            let x = CGFloat(i) * cellW + cellW / 2
            let headRow = Int(col.head.rounded(.down))
            for k in 0...trail {
                let row = headRow - k
                guard row >= 0, row < rows else { continue }
                let ch = col.chars[row % col.chars.count]
                let y = CGFloat(row) * cellH + cellH / 2
                if k == 0 {
                    if headCache[ch] == nil {
                        headCache[ch] = ctx.resolve(Text(String(ch)).font(font).foregroundStyle(headCol))
                    }
                    ctx.opacity = 1
                    ctx.draw(headCache[ch]!, at: CGPoint(x: x, y: y))
                } else {
                    if bodyCache[ch] == nil {
                        bodyCache[ch] = ctx.resolve(Text(String(ch)).font(font).foregroundStyle(bodyCol))
                    }
                    ctx.opacity = pow(1.0 - Double(k) / (trailF + 1.0), 1.35) * 0.95
                    ctx.draw(bodyCache[ch]!, at: CGPoint(x: x, y: y))
                }
            }
        }
        ctx.opacity = 1
    }

    // ---------- 全屏窗口 ----------

    override func makePanel(_ size: Int) -> NSPanel {
        let p = MatrixPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        configure(p)
        return p
    }

    override func initialLocation() {
        guard let screen = NSScreen.main, let p = panel else { return }
        p.setFrame(screen.frame, display: true)   // 铺满主屏（含菜单栏区域；菜单栏层级更高仍可点）
    }

    override func show() {
        super.show()
        NSApp.activate(ignoringOtherApps: true)   // 雨幕接管键盘，ESC 才收得到
        panel?.makeKey()
    }

    // ---------- 托盘徽章 ----------

    @MainActor override func makeBadge() -> NSImage {
        let r = ImageRenderer(content: MatrixBadge())
        r.scale = 2   // 位图 2 倍采样，缩到菜单栏 18pt 仍清晰
        return r.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}

/// 无边框面板默认 canBecomeKey = false，收不到 keyDown（ESC 退出需要它）
final class MatrixPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct MatrixBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.01, green: 0.03, blue: 0.02))
            RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.12, green: 0.65, blue: 0.30), lineWidth: 1.5)
            Text("雨").font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(red: 0.55, green: 1.0, blue: 0.65))
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color(red: 0.12, green: 0.84, blue: 0.38))
                    .frame(width: 2.6, height: 2.6)
                    .offset(x: -11 + CGFloat(i) * 10, y: 18 - CGFloat(i) * 4)
            }
        }
        .frame(width: 64, height: 64)
    }
}
