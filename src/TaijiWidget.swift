import SwiftUI
import AppKit

// MARK: - 挂件类别二：玉环太极

/// 玉环镶珠 + 阴阳鱼。最简挂件范例：一个转速、一个尺寸，两个设置项。
class TaijiWidget: DesktopWidget {
    static let INK = rgb(0x1A1F2A)
    static let IVORY = rgb(0xF3E6C8)
    static let JADE = rgb(0x7FB8A4)
    static let JADED = rgb(0x4E8272)
    static let NIGHT = rgb(0x14202B)

    var angle = 0.0
    var elapsed = 0.0
    var speed = 12

    override init() {
        super.init()
        speed = intVal("speed", 12)
    }

    override var id: String { "taiji" }
    override var name: String { "太极" }
    override var defaultSize: Int { 240 }
    override var designSize: CGFloat { 240 }

    /// 与罗盘错开，别叠在一起
    override func initialOffset() -> CGPoint { CGPoint(x: 240, y: 120) }

    override var settings: [Setting] {
        [
            .num("speed", "旋转速度（°/秒）", -60, 60, 12),
            .num("size", "圆盘大小（px）", 160, 400, 240),
        ]
    }

    override func applySetting(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefKey(key))
        if key == "size" {
            resize(Int(value) ?? defaultSize)
        } else if key == "speed" {
            speed = Int(value) ?? 12
        }
    }

    override func tick(dt: TimeInterval) {
        angle += Double(speed) * dt
        elapsed += dt
    }

    override func draw(_ ctx: inout GraphicsContext) {
        let R = 80.0

        // 玉环底盘 + 双圈描边
        disc(&ctx, 118, Self.NIGHT)
        ring(&ctx, 118, 2.5, Self.JADE)
        ring(&ctx, 110, 1.5, Self.JADED)

        // 环上十六珠，随时间柔和呼吸
        let alpha = 0.82 + 0.18 * sin(elapsed * 1.6)
        let bead = Self.JADE.opacity(alpha)
        for i in 0..<16 {
            let th = Double(i) * 2 * .pi / 16
            let x = 100 * sin(th), y = -100 * cos(th)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 3.4, y: y - 3.4, width: 6.8, height: 6.8)),
                     with: .color(bead))
        }
        ring(&ctx, 88, 1.2, Self.JADED)

        // 阴阳鱼：整体随 angle 旋转（副本 = save/restore）
        var c = ctx
        c.rotate(by: .degrees(angle))

        // 底：白鱼全圆
        c.fill(Path(ellipseIn: CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)),
               with: .color(Self.IVORY))
        // 黑鱼：半圆（弦 = 竖直直径）。SwiftUI 角度系 0° = 3 点钟方向、y 向下；
        // clockwise: false = 角度递增方向（270°→0°→90°，扫过右半平面），
        // 屏幕方向与参数名相反是 SwiftUI 的坑，closeSubpath 补上直径弦
        var half = Path()
        half.addArc(center: .zero, radius: R,
                    startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
        half.closeSubpath()
        c.fill(half, with: .color(Self.INK))
        // 鱼身：S 曲线两个小圆
        c.fill(Path(ellipseIn: CGRect(x: -R / 2, y: -R, width: R, height: R)),
               with: .color(Self.INK))     // 上半收窄为黑（圆心 (0,-R/2)）
        c.fill(Path(ellipseIn: CGRect(x: -R / 2, y: 0, width: R, height: R)),
               with: .color(Self.IVORY))   // 下半放白（圆心 (0, R/2)）
        // 鱼眼
        c.fill(Path(ellipseIn: CGRect(x: -R / 8, y: -R / 2 - R / 8, width: R / 4, height: R / 4)),
               with: .color(Self.IVORY))
        c.fill(Path(ellipseIn: CGRect(x: -R / 8, y: R / 2 - R / 8, width: R / 4, height: R / 4)),
               with: .color(Self.INK))
    }

    func disc(_ ctx: inout GraphicsContext, _ r: Double, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .color(c))
    }

    func ring(_ ctx: inout GraphicsContext, _ r: Double, _ w: Double, _ c: Color) {
        ctx.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                   with: .color(c), lineWidth: w)
    }

    // ---------- 托盘徽章 ----------

    @MainActor override func makeBadge() -> NSImage {
        let r = ImageRenderer(content: TaijiBadge())
        r.scale = 2   // 位图 2 倍采样，缩到菜单栏 18pt 仍清晰
        return r.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}

struct TaijiBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(TaijiWidget.NIGHT).frame(width: 60, height: 60)
            Circle().stroke(TaijiWidget.JADE, lineWidth: 3).frame(width: 58, height: 58)
            InkHalfShape().fill(TaijiWidget.INK).frame(width: 48, height: 48)
            Circle().fill(TaijiWidget.INK).frame(width: 24, height: 24).offset(y: -12)
            Circle().fill(TaijiWidget.IVORY).frame(width: 24, height: 24).offset(y: 12)
            Circle().fill(TaijiWidget.IVORY).frame(width: 6, height: 6).offset(y: -12)
            Circle().fill(TaijiWidget.INK).frame(width: 6, height: 6).offset(y: 12)
        }
        .frame(width: 64, height: 64)
    }
}

struct InkHalfShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}
