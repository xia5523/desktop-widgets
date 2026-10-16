import SwiftUI
import AppKit

// MARK: - 挂件类别三：古风宫灯

/// 红纱宫灯：烛光呼吸 + 整灯绕挂点轻摆 + 流苏滞后摆动，灯面吉字可换。
class LanternWidget: DesktopWidget {
    static let RED = rgb(0xC8362B)
    static let RED_D = rgb(0x8E1F1A)
    static let GOLD = rgb(0xE6C15C)
    static let GOLD_L = rgb(0xF7E3A0)
    static let GOLD_D = rgb(0xB8862B)
    static let HALO = rgb(0xFF9A3D)
    static let GLYPHS = ["福", "囍", "春", "燈", "无字"]
    static let GLYPH_FONT = Font.custom("Kaiti SC", size: 62).weight(.bold)

    var elapsed = 0.0
    var swaySpeed = 8, swayAmp = 5, glow = 60
    var glyph = "福"

    override init() {
        super.init()
        loadConfig()
    }

    override var id: String { "lantern" }
    override var name: String { "灯笼" }
    override var defaultSize: Int { 320 }
    override var designSize: CGFloat { 360 }
    override func initialOffset() -> CGPoint { CGPoint(x: -250, y: 140) }

    func loadConfig() {
        swaySpeed = intVal("sway.speed", 8)
        swayAmp = intVal("sway.amp", 5)
        glow = intVal("glow", 60)
        glyph = strVal("glyph", "福")
    }

    override var settings: [Setting] {
        [
            .num("sway.speed", "摆动速度", 0, 40, 8),
            .num("sway.amp", "摆动幅度（°）", 0, 15, 5),
            .num("glow", "烛光亮度", 0, 100, 60),
            .choice("glyph", "灯面吉字", Self.GLYPHS, "福"),
            .num("size", "挂件大小（px）", 200, 440, 320),
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

    override func draw(_ ctx: inout GraphicsContext) {
        // 整灯绕挂点轻摆
        let sway = Double(swayAmp) * sin(elapsed * 1.1 * Double(swaySpeed) / 8.0)
        var c = ctx
        c.translateBy(x: 0, y: -158)
        c.rotate(by: .degrees(sway))
        c.translateBy(x: 0, y: 158)

        // 烛光呼吸晕（三层暖光近似辉光）
        let breath = 0.8 + 0.2 * sin(elapsed * 1.4)
        let g = Double(glow) / 100.0
        disc(&c, 158, Self.HALO.opacity(0.035 * g * breath))
        disc(&c, 138, Self.HALO.opacity(0.06 * g * breath))
        disc(&c, 116, Self.HALO.opacity(0.10 * g * breath))

        // 灯体（椭圆，中心 (0,-14)）
        let body = CGRect(x: -102, y: -114, width: 204, height: 200)
        c.fill(Path(ellipseIn: body), with: .color(Self.RED))
        // 纱面柔光
        c.fill(Path(ellipseIn: CGRect(x: -66, y: -86, width: 60, height: 40)),
              with: .color(Color.white.opacity(0.10)))
        // 竖向骨架（经线椭圆）
        for rx in [74.0, 40.0] {
            c.stroke(Path(ellipseIn: CGRect(x: -rx, y: -114, width: 2 * rx, height: 200)),
                     with: .color(Self.RED_D), lineWidth: 2.0)
        }
        c.stroke(Path(ellipseIn: body), with: .color(Self.GOLD), lineWidth: 2.6)

        // 灯面吉字
        if glyph != "无字" {
            let t = c.resolve(Text(glyph).font(Self.GLYPH_FONT).foregroundStyle(Self.GOLD_L))
            c.draw(t, at: CGPoint(x: 0, y: -14))
        }

        // 上盖（灯顶宝盖）：底边深嵌灯身椭圆内，两侧不留缝
        var capTop = Path()
        capTop.move(to: CGPoint(x: -16, y: -146))
        capTop.addLine(to: CGPoint(x: -58, y: -96))
        capTop.addQuadCurve(to: CGPoint(x: 58, y: -96), control: CGPoint(x: 0, y: -84))
        capTop.addLine(to: CGPoint(x: 16, y: -146))
        capTop.addQuadCurve(to: CGPoint(x: -16, y: -146), control: CGPoint(x: 0, y: -152))
        capTop.closeSubpath()
        c.fill(capTop, with: .color(Self.GOLD))
        c.stroke(capTop, with: .color(Self.GOLD_D), lineWidth: 1.5)

        // 下座：顶边弧度贴着灯身椭圆收进去
        var capBot = Path()
        capBot.move(to: CGPoint(x: -58, y: 66))
        capBot.addQuadCurve(to: CGPoint(x: 58, y: 66), control: CGPoint(x: 0, y: 92))
        capBot.addLine(to: CGPoint(x: 18, y: 104))
        capBot.addQuadCurve(to: CGPoint(x: -18, y: 104), control: CGPoint(x: 0, y: 109))
        capBot.closeSubpath()
        c.fill(capBot, with: .color(Self.GOLD))
        c.stroke(capBot, with: .color(Self.GOLD_D), lineWidth: 1.5)

        // 挂环 + 灯绳（绳稍长，悬垂感）
        var hook = Path()
        hook.addArc(center: CGPoint(x: 0, y: -166), radius: 7,
                    startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        c.stroke(hook, with: .color(Self.GOLD), lineWidth: 2.4)
        var rope = Path()
        rope.move(to: CGPoint(x: 0, y: -159))
        rope.addLine(to: CGPoint(x: 0, y: -148))
        c.stroke(rope, with: .color(Self.GOLD_D), lineWidth: 2.4)

        // 流苏：绕穗根滞后摆动；穗有长短差与开合，中长侧短
        let sway2 = Double(swayAmp) * 1.6 * sin(elapsed * 1.1 * Double(swaySpeed) / 8.0 - 0.9)
        var tc = c
        tc.translateBy(x: 0, y: 104)
        tc.rotate(by: .degrees(sway2))
        tc.translateBy(x: 0, y: -104)

        var cord = Path()
        cord.move(to: CGPoint(x: 0, y: 106))
        cord.addLine(to: CGPoint(x: 0, y: 120))
        tc.stroke(cord, with: .color(Self.GOLD_D), lineWidth: 2.5)
        tc.fill(Path(ellipseIn: CGRect(x: -8, y: 120, width: 16, height: 12)), with: .color(Self.GOLD))
        for i in -3...3 {
            let x0 = Double(i) * 4.6
            let drop = 152.0 + Double(3 - abs(i)) * 4.0   // 中间长、两侧短
            var s = Path()
            s.move(to: CGPoint(x: x0, y: 134))
            s.addQuadCurve(to: CGPoint(x: x0 * 1.35, y: drop),
                           control: CGPoint(x: x0 * 1.1, y: (134 + drop) / 2))
            tc.stroke(s, with: .color(Self.RED_D),
                      style: StrokeStyle(lineWidth: 3.0 - Double(abs(i)) * 0.25, lineCap: .round))
        }
    }

    func disc(_ ctx: inout GraphicsContext, _ r: Double, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .color(c))
    }

    // ---------- 托盘徽章 ----------

    @MainActor override func makeBadge() -> NSImage {
        let r = ImageRenderer(content: LanternBadge())
        r.scale = 2   // 位图 2 倍采样，缩到菜单栏 18pt 仍清晰
        return r.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}

struct LanternBadge: View {
    var body: some View {
        ZStack {
            Ellipse().fill(LanternWidget.RED).frame(width: 34, height: 30)
            Ellipse().stroke(LanternWidget.GOLD, lineWidth: 2).frame(width: 34, height: 30)
            RoundedRectangle(cornerRadius: 2).fill(LanternWidget.GOLD).frame(width: 18, height: 5).offset(y: -17)
            RoundedRectangle(cornerRadius: 2).fill(LanternWidget.GOLD).frame(width: 18, height: 5).offset(y: 17)
            Rectangle().fill(LanternWidget.GOLD_D).frame(width: 2, height: 10).offset(y: 24)
        }
        .frame(width: 64, height: 64)
    }
}
