import SwiftUI
import AppKit

// MARK: - 调色板

struct Palette {
    let goldL, gold, goldD, verm, redD, blueD, night, ivory, ink: Color
}

func rgb(_ v: UInt32) -> Color {
    Color(red: Double((v >> 16) & 0xFF) / 255,
          green: Double((v >> 8) & 0xFF) / 255,
          blue: Double(v & 0xFF) / 255)
}

// MARK: - 挂件类别一：古风旋转罗盘

/// 同心环（外→内）：联珠纹 → 地支十二字 → 回纹 → 祥云 → 中央团花，
/// 各环转速、圆盘大小、配色样式均可独立设置并持久化。角度一律按度累积。
class CompassWidget: DesktopWidget {
    static let TANG = Palette(
        goldL: rgb(0xF7E3A0), gold: rgb(0xE6C15C), goldD: rgb(0xB8862B),
        verm: rgb(0x8C231E), redD: rgb(0x5E1614), blueD: rgb(0x1C2E52),
        night: rgb(0x14223E), ivory: rgb(0xF3E6C8), ink: rgb(0x0E121E))
    static let BRONZE = Palette(
        goldL: rgb(0xDCE8D0), gold: rgb(0x9FC7A6), goldD: rgb(0x6A8F6B),
        verm: rgb(0x77502A), redD: rgb(0x4A341E), blueD: rgb(0x43503F),
        night: rgb(0x333D31), ivory: rgb(0xE9E4CE), ink: rgb(0x20261E))
    static let INKP = Palette(
        goldL: rgb(0xFFFFFF), gold: rgb(0xC9CDD3), goldD: rgb(0x7C838C),
        verm: rgb(0x3A3F47), redD: rgb(0x262A30), blueD: rgb(0x33373E),
        night: rgb(0x22252B), ivory: rgb(0xF5F5F2), ink: rgb(0x15171B))

    static let STYLE_NAMES = ["唐风金朱", "青铜古锈", "水墨玄玉"]
    static let PALETTES: [Palette] = [TANG, BRONZE, INKP]
    static let BRANCHES = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    static let BRANCH_FONT = Font.custom("Kaiti SC", size: 27).weight(.bold)

    // 运行状态
    var pal = TANG
    var sGlobal = 0, sPearl = 0, sChar = 0, sMeander = 0, sCloud = 0, sFlower = 0
    var global = 0.0, aPearl = 0.0, aChar = 0.0, aMeander = 0.0, aCloud = 0.0, aFlower = 0.0, elapsed = 0.0
    var wheelFactor = 1.0

    override init() {
        super.init()
        loadConfig()
    }

    override var id: String { "compass" }
    override var name: String { "罗盘" }
    override var defaultSize: Int { 360 }
    override var designSize: CGFloat { 360 }

    func loadConfig() {
        sGlobal = intVal("speed.global", 4)
        sPearl = intVal("speed.pearl", 16)
        sChar = intVal("speed.char", -26)
        sMeander = intVal("speed.meander", 32)
        sCloud = intVal("speed.cloud", -46)
        sFlower = intVal("speed.flower", 10)
        let style = strVal("style", Self.STYLE_NAMES[0])
        pal = Self.TANG
        for (i, n) in Self.STYLE_NAMES.enumerated() where n == style {
            pal = Self.PALETTES[i]
        }
    }

    // ---------- 设置 ----------

    override var settings: [Setting] {
        [
            .num("speed.global", "整体转速（°/秒）", -30, 60, 4),
            .num("speed.pearl", "联珠纹转速", -60, 60, 16),
            .num("speed.char", "地支环转速", -60, 60, -26),
            .num("speed.meander", "回纹带转速", -60, 60, 32),
            .num("speed.cloud", "祥云带转速", -60, 60, -46),
            .num("speed.flower", "团花转速", -60, 60, 10),
            .num("size", "圆盘大小（px）", 200, 480, 360),
            .choice("style", "样式", Self.STYLE_NAMES, Self.STYLE_NAMES[0]),
        ]
    }

    override func applySetting(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefKey(key))
        switch key {
        case "size": resize(Int(value) ?? defaultSize)
        default: loadConfig()   // style 与转速类，下一拍生效
        }
    }

    override func addQuickItems(_ mb: TrayMenuBuilder, _ sub: NSMenu) {
        let styleMenu = mb.submenu("样式", in: sub)
        for st in Self.STYLE_NAMES {
            styleMenu.addItem(mb.item(st) { [weak self] in self?.applySetting("style", st) })
        }
        let sizeMenu = mb.submenu("大小", in: sub)
        let names = ["小", "中", "大"]
        let sizes = [260, 360, 480]
        for (n, sz) in zip(names, sizes) {
            sizeMenu.addItem(mb.item("\(n)（\(sz)px）") { [weak self] in
                self?.applySetting("size", String(sz))
            })
        }
    }

    // ---------- 动画 ----------

    override func tick(dt: TimeInterval) {
        let f = wheelFactor * dt
        global += Double(sGlobal) * f
        aPearl += Double(sPearl) * f
        aChar += Double(sChar) * f
        aMeander += Double(sMeander) * f
        aCloud += Double(sCloud) * f
        aFlower += Double(sFlower) * f
        elapsed += f
    }

    override func onWheel(_ units: Int) {
        wheelFactor *= units < 0 ? 1.25 : 0.8
        wheelFactor = min(10, max(0.05, wheelFactor))
    }

    // ---------- 绘制 ----------

    override func draw(_ ctx: inout GraphicsContext) {
        // 静态底盘：由外向内一圈圈叠
        disc(&ctx, 180, pal.ink)
        disc(&ctx, 175, pal.redD)
        disc(&ctx, 165, pal.goldD)
        disc(&ctx, 162, pal.blueD)
        disc(&ctx, 128, pal.goldD)
        disc(&ctx, 125, pal.verm)
        disc(&ctx, 89, pal.goldD)
        disc(&ctx, 86, pal.night)
        disc(&ctx, 56, pal.goldD)
        disc(&ctx, 53, pal.verm)
        ring(&ctx, 177, 5, Color.black.opacity(110.0 / 255))
        ring(&ctx, 179, 3, pal.gold)

        pearls(&ctx, global + aPearl)
        branches(&ctx, global + aChar)
        meander(&ctx, global + aMeander)
        clouds(&ctx, global + aCloud)
        medallion(&ctx, global + aFlower)
    }

    func disc(_ ctx: inout GraphicsContext, _ r: Double, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .color(c))
    }

    func ring(_ ctx: inout GraphicsContext, _ r: Double, _ w: Double, _ c: Color) {
        ctx.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                   with: .color(c), lineWidth: w)
    }

    /// 联珠纹：一圈金珠整体柔和呼吸
    func pearls(_ ctx: inout GraphicsContext, _ angDeg: Double) {
        let n = 40
        let a = 0.82 + 0.18 * sin(elapsed * 1.6)
        let c = pal.goldL.opacity(a)
        for i in 0..<n {
            let th = angDeg * .pi / 180 + Double(i) * 2 * .pi / Double(n)
            let x = 170 * sin(th), y = -170 * cos(th)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(c))
        }
    }

    /// 地支十二字环 + 间隔小菱花
    func branches(_ ctx: inout GraphicsContext, _ angDeg: Double) {
        let rad = angDeg * .pi / 180
        for (i, ch) in Self.BRANCHES.enumerated() {
            let th = rad + Double(i) * 2 * .pi / 12
            let x = 145 * sin(th), y = -145 * cos(th)
            let rt = ctx.resolve(Text(ch).font(Self.BRANCH_FONT).foregroundStyle(pal.ivory))
            ctx.draw(rt, at: CGPoint(x: x, y: y))
            let td = rad + (Double(i) + 0.5) * 2 * .pi / 12
            diamond(&ctx, 145 * sin(td), -145 * cos(td), 4.5, pal.gold)
        }
    }

    func diamond(_ ctx: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ c: Color) {
        var p = Path()
        p.move(to: CGPoint(x: x, y: y - r))
        p.addLine(to: CGPoint(x: x + r, y: y))
        p.addLine(to: CGPoint(x: x, y: y + r))
        p.addLine(to: CGPoint(x: x - r, y: y))
        p.closeSubpath()
        ctx.fill(p, with: .color(c))
    }

    /// 回纹带：首尾相接的回字纹单元
    /// SwiftUI 的 save/restore = 值拷贝：副本共享绘制目标但变换独立，丢弃即还原
    func meander(_ ctx: inout GraphicsContext, _ angDeg: Double) {
        let style = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        let key = keyPattern()
        for i in 0..<26 {
            var c = ctx
            c.rotate(by: .degrees(angDeg + Double(i) * 360.0 / 26))
            c.translateBy(x: 0, y: -107)
            c.stroke(key, with: .color(pal.gold), style: style)
        }
    }

    /// 回纹单元（以单元中心为原点，约 20x20）
    func keyPattern() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -10, y: 10))
        p.addLine(to: CGPoint(x: -10, y: -10))
        p.addLine(to: CGPoint(x: 10, y: -10))
        p.addLine(to: CGPoint(x: 10, y: 6))
        p.addLine(to: CGPoint(x: -2, y: 6))
        p.addLine(to: CGPoint(x: -2, y: -2))
        p.addLine(to: CGPoint(x: 4, y: -2))
        return p
    }

    /// 祥云带：如意云头（三拱层叠 + 渐细云尾）
    func clouds(_ ctx: inout GraphicsContext, _ angDeg: Double) {
        for i in 0..<8 {
            var c = ctx
            c.rotate(by: .degrees(angDeg + Double(i) * 360.0 / 8))
            c.translateBy(x: 0, y: -71)
            cloud(&c)
        }
    }

    /// 如意云：先云尾、再两侧小拱、最后中拱压上（层叠出层次）。
    /// 局部坐标 y 向下，云头坐在底线 y=+7 上，整体落在夜色环带（r 56~86）内。
    func cloud(_ ctx: inout GraphicsContext) {
        let edge = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)

        // 云尾：向右渐细的飘带，尾尖上挑
        var tail = Path()
        tail.move(to: CGPoint(x: 6.0, y: 0.6))
        tail.addQuadCurve(to: CGPoint(x: 19.0, y: 2.2), control: CGPoint(x: 12.0, y: 0.0))
        tail.addQuadCurve(to: CGPoint(x: 7.0, y: 6.8), control: CGPoint(x: 13.0, y: 4.4))
        tail.closeSubpath()
        ctx.fill(tail, with: .color(pal.ivory))
        ctx.stroke(tail, with: .color(pal.verm), style: edge)

        // 三拱云头：中拱最后画，盖住两侧拱的内侧描边形成如意层叠。
        // 注意 SwiftUI 的 clockwise 在 y-down 系里是"视觉逆时针"：180°→360° 配
        // clockwise: false 才向上拱（经过 270°/正上方）。侧拱外移让层叠更明显
        for (x, r) in [(-12.8, 5.6), (5.8, 5.6), (-3.5, 9.2)] {
            var d = Path()
            d.addArc(center: CGPoint(x: x, y: 7), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            d.closeSubpath()
            ctx.fill(d, with: .color(pal.ivory))
            ctx.stroke(d, with: .color(pal.verm), style: edge)
        }

        // 云心卷纹：中拱内一条开口向右下的 C 形小卷
        var scroll = Path()
        scroll.move(to: CGPoint(x: -0.8, y: 2.2))
        scroll.addQuadCurve(to: CGPoint(x: -6.8, y: 1.4), control: CGPoint(x: -6.2, y: 5.2))
        scroll.addQuadCurve(to: CGPoint(x: -3.4, y: -2.2), control: CGPoint(x: -7.0, y: -2.4))
        ctx.stroke(scroll, with: .color(pal.verm),
                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }

    /// 中央团花：八瓣大莲 + 错位八瓣小莲 + 联珠 + 中心宝珠
    /// 先全部填充再统一描边，避免相邻瓣互相压线
    func medallion(_ ctx: inout GraphicsContext, _ angDeg: Double) {
        var c = ctx
        c.rotate(by: .degrees(angDeg))
        ring(&c, 49, 1.2, pal.goldD)
        for i in 0..<8 { petal(&c, 10.5, 32, Double(i) * 45, fill: pal.goldL) }
        for i in 0..<8 { petal(&c, 8.0, 24, Double(i) * 45 + 22.5, fill: pal.ivory) }
        for i in 0..<8 { petal(&c, 10.5, 32, Double(i) * 45, stroke: pal.verm) }
        for i in 0..<8 { petal(&c, 8.0, 24, Double(i) * 45 + 22.5, stroke: pal.verm) }
        let gold = pal.gold
        for i in 0..<8 {
            let th = (Double(i) * 45 + 22.5) * .pi / 180
            c.fill(Path(ellipseIn: CGRect(x: 47 * sin(th) - 2.4, y: -47 * cos(th) - 2.4,
                                          width: 4.8, height: 4.8)), with: .color(gold))
        }
        disc(&c, 11, pal.goldL)
        ring(&c, 11, 1.5, pal.verm)
        disc(&c, 5, pal.verm)
        disc(&c, 2, pal.ivory)
    }

    /// 莲瓣：从内半径 14 伸展到 tip，两段二次曲线合拢；fill / stroke 二选一
    func petal(_ ctx: inout GraphicsContext, _ halfW: Double, _ len: Double, _ thDeg: Double,
               fill: Color? = nil, stroke: Color? = nil) {
        var c = ctx
        c.rotate(by: .degrees(thDeg))
        let tip = 14.0 + len, mid = 14.0 + len * 0.55
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -14))
        p.addQuadCurve(to: CGPoint(x: 0, y: -tip), control: CGPoint(x: halfW, y: -mid))
        p.addQuadCurve(to: CGPoint(x: 0, y: -14), control: CGPoint(x: -halfW, y: -mid))
        p.closeSubpath()
        if let col = fill {
            c.fill(p, with: .color(col))
        } else if let col = stroke {
            c.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 1.4))
        }
    }

    // ---------- 托盘徽章 ----------

    @MainActor override func makeBadge() -> NSImage {
        let r = ImageRenderer(content: CompassBadge(pal: pal))
        r.scale = 2   // 位图 2 倍采样，缩到菜单栏 18pt 仍清晰
        return r.nsImage ?? NSImage(size: NSSize(width: 64, height: 64))
    }
}

struct PetalBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - 7))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 22), control: CGPoint(x: c.x + 5.5, y: c.y - 14))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 7), control: CGPoint(x: c.x - 5.5, y: c.y - 14))
        p.closeSubpath()
        return p
    }
}

struct CompassBadge: View {
    let pal: Palette
    var body: some View {
        ZStack {
            Circle().fill(pal.night).frame(width: 60, height: 60)
            Circle().stroke(pal.gold, lineWidth: 5).frame(width: 58, height: 58)
            Circle().stroke(pal.goldD, lineWidth: 3).frame(width: 50, height: 50)
            ForEach(0..<8, id: \.self) { i in
                PetalBadgeShape().fill(pal.goldL)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle().fill(pal.goldL).frame(width: 14, height: 14)
            Circle().stroke(pal.verm, lineWidth: 2.4).frame(width: 14, height: 14)
            Circle().fill(pal.verm).frame(width: 6.4, height: 6.4)
            Circle().fill(pal.ivory).frame(width: 2.4, height: 2.4)
        }
        .frame(width: 64, height: 64)
    }
}
