import SwiftUI
import AppKit

// MARK: - 挂件类别四：日晷时辰钟

/// 十二时辰真时钟：子在正上、午在正下（古制），昼夜针一天一圈指向时辰，
/// 分针一小时一圈，秒是一颗带彗尾的绕行明珠；当前时辰字呼吸高亮。
/// 刻度取古法"一昼夜九十六刻"。
class ClockWidget: DesktopWidget {
    static let INK = rgb(0x0E121E)
    static let RED_D = rgb(0x5E1614)
    static let GOLD = rgb(0xE6C15C)
    static let GOLD_L = rgb(0xF7E3A0)
    static let GOLD_D = rgb(0xB8862B)
    static let BLUE_D = rgb(0x1C2E52)
    static let VERM = rgb(0x8C231E)
    static let IVORY = rgb(0xF3E6C8)

    static let BRANCHES = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    static let BRANCH_FONT = Font.custom("Kaiti SC", size: 26).weight(.bold)
    static let BRANCH_FONT_HI = Font.custom("Kaiti SC", size: 31).weight(.bold)

    var elapsed = 0.0
    var showSeconds = true

    override init() {
        super.init()
        loadConfig()
    }

    override var id: String { "clock" }
    override var name: String { "时辰钟" }
    override var defaultSize: Int { 300 }
    override var designSize: CGFloat { 360 }
    override func initialOffset() -> CGPoint { CGPoint(x: 0, y: -270) }

    func loadConfig() {
        showSeconds = boolVal("seconds", true)
    }

    override var settings: [Setting] {
        [
            .num("size", "钟面大小（px）", 240, 440, 300),
            .bool("seconds", "显示秒珠", true),
        ]
    }

    override func applySetting(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefKey(key))
        if key == "size" {
            resize(Int(value) ?? defaultSize)
        } else {
            loadConfig()
        }
    }

    override func tick(dt: TimeInterval) { elapsed += dt }

    // ---------- 绘制 ----------

    /// 角度→坐标：0° = 正上（子位），顺时针为正
    static func pt(_ angDeg: Double, _ r: Double) -> CGPoint {
        let a = angDeg * Double.pi / 180
        return CGPoint(x: r * sin(a), y: -r * cos(a))
    }

    override func draw(_ ctx: inout GraphicsContext) {
        // 真实时间（含亚秒，保证秒珠平滑）
        let cal = Calendar.current
        let h = Double(cal.component(.hour, from: Date()))
        let m = Double(cal.component(.minute, from: Date()))
        let s = Double(cal.component(.second, from: Date()))
            + Double(cal.component(.nanosecond, from: Date())) / 1e9
        let t = h * 3600 + m * 60 + s
        let dayAng = t / 86400 * 360                    // 昼夜针：一天一圈，0 = 子
        let minAng = t.truncatingRemainder(dividingBy: 3600) / 3600 * 360   // 分针：一小时一圈
        let secAng = t.truncatingRemainder(dividingBy: 60) / 60 * 360       // 秒珠：一分钟一圈
        let branchIdx = Int(((Int(h) + 1) % 24) / 2)    // 当前时辰（23-1 点为子）

        // 底盘
        disc(&ctx, 180, Self.INK)
        disc(&ctx, 175, Self.RED_D)
        disc(&ctx, 165, Self.GOLD_D)
        disc(&ctx, 161, Self.BLUE_D)
        ring(&ctx, 154, 1.5, Self.GOLD)

        // 九十六刻刻度：每 8 格为一时辰起点（长刻）
        for i in 0..<96 {
            let a = Double(i) * 3.75
            if i % 8 == 0 {
                tick(&ctx, a, 141, 152, 2.2, Self.GOLD)
            } else {
                tick(&ctx, a, 147, 152, 1.1, Self.GOLD_D)
            }
        }

        // 十二时辰字；当前时辰呼吸高亮
        let breath = 0.6 + 0.4 * sin(elapsed * 2.0)
        for (i, ch) in Self.BRANCHES.enumerated() {
            let p = Self.pt(Double(i) * 30, 118)
            if i == branchIdx {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)),
                         with: .color(Self.GOLD.opacity(0.20 * breath + 0.10)))
                let t = ctx.resolve(Text(ch).font(Self.BRANCH_FONT_HI).foregroundStyle(Self.GOLD_L))
                ctx.draw(t, at: p)
            } else {
                let t = ctx.resolve(Text(ch).font(Self.BRANCH_FONT).foregroundStyle(Self.IVORY.opacity(0.72)))
                ctx.draw(t, at: p)
            }
        }

        // 秒珠 + 彗尾
        if showSeconds {
            var trail = Path()
            trail.addArc(center: .zero, radius: 134,
                         startAngle: .degrees(secAng - 40 - 90), endAngle: .degrees(secAng - 90),
                         clockwise: false)
            ctx.stroke(trail, with: .color(Self.IVORY.opacity(0.30)),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            let sp = Self.pt(secAng, 134)
            ctx.fill(Path(ellipseIn: CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)),
                     with: .color(Self.IVORY))
        }

        // 分针（朱红）、昼夜针（金，指向时辰）
        hand(&ctx, minAng, 112, 4.5, 16, Self.VERM)
        hand(&ctx, dayAng, 92, 8.0, 22, Self.GOLD_L)

        // 中枢团花
        disc(&ctx, 11, Self.GOLD_L)
        ring(&ctx, 11, 1.5, Self.VERM)
        disc(&ctx, 4.5, Self.VERM)
    }

    func disc(_ ctx: inout GraphicsContext, _ r: Double, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .color(c))
    }
    func ring(_ ctx: inout GraphicsContext, _ r: Double, _ w: Double, _ c: Color) {
        ctx.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                   with: .color(c), lineWidth: w)
    }
    func tick(_ ctx: inout GraphicsContext, _ ang: Double, _ r1: Double, _ r2: Double,
              _ w: Double, _ c: Color) {
        var p = Path()
        p.move(to: Self.pt(ang, r1))
        p.addLine(to: Self.pt(ang, r2))
        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }
    /// 指针：尖端朝上画，随 ang 旋转；len 长度、w 半宽、tail 尾锤长度
    func hand(_ ctx: inout GraphicsContext, _ ang: Double, _ len: Double, _ w: Double,
              _ tail: Double, _ c: Color) {
        var h = ctx
        h.rotate(by: .degrees(ang))
        var p = Path()
        p.move(to: CGPoint(x: 0, y: tail))
        p.addLine(to: CGPoint(x: -w, y: 0))
        p.addLine(to: CGPoint(x: 0, y: -len))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.closeSubpath()
        h.fill(p, with: .color(c))
    }

    // ---------- 托盘徽章 ----------

    @MainActor override func makeBadge() -> NSImage {
        let r = ImageRenderer(content: ClockBadge())
        r.scale = 2   // 位图 2 倍采样，缩到菜单栏 18pt 仍清晰
        return r.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}

struct ClockBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(ClockWidget.BLUE_D).frame(width: 54, height: 54)
            Circle().stroke(ClockWidget.GOLD, lineWidth: 4).frame(width: 52, height: 52)
            Capsule().fill(ClockWidget.GOLD_L).frame(width: 5, height: 22).offset(y: -9)
            Capsule().fill(ClockWidget.VERM).frame(width: 3.5, height: 28).rotationEffect(.degrees(120))
            Circle().fill(ClockWidget.VERM).frame(width: 9, height: 9)
            Circle().fill(ClockWidget.IVORY).frame(width: 5, height: 5).offset(y: -19)
        }
        .frame(width: 64, height: 64)
    }
}
