import SwiftUI
import AppKit

// MARK: - 挂件类别五：三勾玉写轮眼

/// 红瞳 + 黑瞳 + 三枚勾玉围绕瞳孔 120° 分布，整组缓缓转动。
/// 径向渐变用同心圆离散逼近（GraphicsContext 只有线性渐变）。
class SharinganWidget: DesktopWidget {
    static let BLACK = rgb(0x0A0406)
    static let RIM_U: UInt32 = 0x6E0B10       // 瞳缘深红
    static let CENTER_U: UInt32 = 0xE83A2C    // 瞳心亮红
    static let CENTER = rgb(0xE83A2C) // 同上，给徽章用
    static let RING = rgb(0x2B0608)

    var angle = 0.0
    var speed = 5

    override init() {
        super.init()
        speed = intVal("speed", 5)
    }

    override var id: String { "sharingan" }
    override var name: String { "写轮眼" }
    override var defaultSize: Int { 300 }
    override var designSize: CGFloat { 360 }
    override func initialOffset() -> CGPoint { CGPoint(x: 250, y: -160) }

    override var settings: [Setting] {
        [
            .num("speed", "勾玉转速（°/秒）", -30, 30, 5),
            .num("size", "挂件大小（px）", 200, 400, 300),
        ]
    }

    override func applySetting(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefKey(key))
        if key == "size" {
            resize(Int(value) ?? defaultSize)
        } else {
            speed = Int(value) ?? 5
        }
    }

    override func tick(dt: TimeInterval) {
        angle += Double(speed) * dt
    }

    // ---------- 绘制 ----------

    override func draw(_ ctx: inout GraphicsContext) {
        // 外缘黑眶
        disc(&ctx, 172, Self.BLACK)
        // 红瞳：同心圆由深到亮逼近径向渐变（165 → 48）
        let steps = 14
        for i in 0..<steps {
            let f = Double(i) / Double(steps - 1)
            disc(&ctx, 165 - 117 * f, lerpRGB(Self.RIM_U, Self.CENTER_U, f))
        }
        // 薄环
        ring(&ctx, 162, 2.2, Self.RING)
        ring(&ctx, 118, 1.6, Self.RING)
        ring(&ctx, 74, 1.4, Self.RING)

        // 三勾玉（整体随 angle 缓转）
        for i in 0..<3 {
            var c = ctx
            c.rotate(by: .degrees(angle + Double(i) * 120))
            tomoe(&c)
        }

        // 黑瞳 + 高光
        disc(&ctx, 46, Self.BLACK)
        ctx.fill(Path(ellipseIn: CGRect(x: -20, y: -152, width: 14, height: 14)),
                 with: .color(Color.white.opacity(0.14)))   // 瞳仁左上柔光
        ctx.fill(Path(ellipseIn: CGRect(x: -17, y: -19, width: 9, height: 9)),
                 with: .color(Color.white.opacity(0.85)))   // 黑瞳高光点
    }

    /// 单枚勾玉（中文逗号形）：胖圆头 + 短肥尾巴。尾巴沿内收螺线
    /// （半径 100→84，尾尖向瞳孔侧卷）向旋转反方向扫约 60°，宽度
    /// w0·(1-f)^0.55——前大半段保持粗壮、只在末端快速收尖；尾根藏在头圆下。
    func tomoe(_ ctx: inout GraphicsContext) {
        var t = Path()
        let steps = 14
        let a0 = -6.0, a1 = -60.0     // 弧角：0° = 头正上，负 = 逆时针侧
        let r0 = 100.0, r1 = 84.0     // 螺线内收
        let w0 = 30.0
        var outer: [CGPoint] = [], inner: [CGPoint] = []
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let rad = (a0 + (a1 - a0) * f) * Double.pi / 180
            let r = r0 + (r1 - r0) * f
            let w = w0 * pow(1 - f, 0.55)            // 前段肥、末段快速收尖
            let cx = r * sin(rad), cy = -r * cos(rad)
            let nx = sin(rad), ny = -cos(rad)        // 径向外法线
            outer.append(CGPoint(x: cx + nx * w / 2, y: cy + ny * w / 2))
            inner.append(CGPoint(x: cx - nx * w / 2, y: cy - ny * w / 2))
        }
        t.move(to: outer[0])
        for p in outer.dropFirst() { t.addLine(to: p) }
        for p in inner.reversed() { t.addLine(to: p) }
        t.closeSubpath()
        ctx.fill(t, with: .color(Self.BLACK))
        // 头（胖圆，略大于尾根宽）
        ctx.fill(Path(ellipseIn: CGRect(x: -21, y: -121, width: 42, height: 42)),
                 with: .color(Self.BLACK))
    }

    func disc(_ ctx: inout GraphicsContext, _ r: Double, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .color(c))
    }
    func ring(_ ctx: inout GraphicsContext, _ r: Double, _ w: Double, _ c: Color) {
        ctx.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                   with: .color(c), lineWidth: w)
    }

    /// 两 RGB 色之间线性插值（SwiftUI Color 分量不可直读，用 UInt32 换算）
    func lerpRGB(_ a: UInt32, _ b: UInt32, _ f: Double) -> Color {
        func ch(_ shift: UInt32) -> Double {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return (x + (y - x) * f) / 255
        }
        return Color(red: ch(16), green: ch(8), blue: ch(0))
    }

    // ---------- 托盘徽章 ----------

    @MainActor override func makeBadge() -> NSImage {
        let r = ImageRenderer(content: SharinganBadge())
        r.scale = 2   // 位图 2 倍采样，缩到菜单栏 18pt 仍清晰
        return r.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}

struct SharinganBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(SharinganWidget.CENTER).frame(width: 52, height: 52)
            Circle().stroke(SharinganWidget.BLACK, lineWidth: 4).frame(width: 52, height: 52)
            Circle().fill(SharinganWidget.BLACK).frame(width: 17, height: 17)
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(SharinganWidget.BLACK).frame(width: 9, height: 9)
                    .offset(y: -15)
                    .rotationEffect(.degrees(Double(i) * 120))
            }
            Circle().fill(Color.white.opacity(0.85)).frame(width: 4, height: 4).offset(x: -6, y: -8)
        }
        .frame(width: 64, height: 64)
    }
}
