import SwiftUI

/// Stateless cyber renderer. `@MainActor` (the `Canvas` closure is main-actor
/// isolated and reads the `@MainActor` engine).
@MainActor
enum FirewallRenderer {

    static func draw(engine e: GameEngine, context ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(x: -16, y: -16, width: size.width + 32, height: size.height + 32)),
                 with: .color(col(0.02, 0.04, 0.05)))
        matrixRain(e, &ctx, size)

        var world = ctx
        if e.shake > 0 {
            world.translateBy(x: .random(in: -e.shake...e.shake) * 0.4,
                              y: .random(in: -e.shake...e.shake) * 0.4)
        }

        drawFirewall(e, &world, size)
        for p in e.packets { drawPacket(e, p, &world) }
        for p in e.particles { drawParticle(p, &world) }

        // feedback flashes
        if e.flashBad > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(col(0.95, 0.15, 0.15, Double(e.flashBad) * 0.4)))
        }
        if e.flashGood > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(col(0.2, 1.0, 0.45, Double(e.flashGood) * 0.22)))
        }
        if e.ddosWarn > 0 {
            let a = Double(min(1, e.ddosWarn)) * (sin(Double(e.elapsed) * 18) > 0 ? 1 : 0.3)
            ctx.stroke(Path(CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)),
                       with: .color(col(1, 0.2, 0.2, a)), lineWidth: 4)
        }

        scanlines(&ctx, size)
        drawHUD(e, &ctx, size)
    }

    // MARK: Background

    private static func matrixRain(_ e: GameEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let t = Double(e.elapsed)
        for i in 0..<14 {
            let x = CGFloat((i * 17) % Int(max(size.width, 1)))
            let sp = 30.0 + Double(i % 5) * 16
            let y = CGFloat((t * sp + Double(i) * 47).truncatingRemainder(dividingBy: Double(size.height + 30)))
            for k in 0..<4 {
                let yy = y - CGFloat(k) * 7
                ctx.fill(Path(CGRect(x: x, y: yy, width: 1.6, height: 4)),
                         with: .color(col(0.2, 0.9, 0.4, 0.16 - Double(k) * 0.035)))
            }
        }
    }

    private static func scanlines(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var path = Path()
        var y: CGFloat = 0
        while y < size.height { path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 3 }
        ctx.fill(path, with: .color(col(0, 0, 0, 0.16)))
    }

    // MARK: Firewall line + server band

    private static func drawFirewall(_ e: GameEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let y = e.coreY
        // protected server band
        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: size.height - y)),
                 with: .color(col(0.04, 0.1, 0.09, 0.9)))
        // the firewall line, colour by integrity
        let frac = Double(clamp(e.integrity / 100, 0, 1))
        let lineColor = mix((1, 0.25, 0.2), (0.2, 1.0, 0.5), frac)
        ctx.fill(Path(CGRect(x: 0, y: y - 2, width: size.width, height: 4)), with: .color(lineColor))
        ctx.fill(Path(CGRect(x: 0, y: y - 6, width: size.width, height: 12)),
                 with: .linearGradient(Gradient(colors: [lineColor.opacity(0.5), lineColor.opacity(0)]),
                                       startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: 0, y: y - 10)))
    }

    // MARK: Packets

    private static func drawPacket(_ e: GameEngine, _ p: Packet, _ ctx: inout GraphicsContext) {
        let r = p.rect()
        let body = Path(roundedRect: r, cornerRadius: 4)
        let (fill, text): (Color, Color)
        switch p.kind {
        case .legit:
            fill = col(0.16, 0.85, 0.4); text = col(0.0, 0.15, 0.05)
        case .threat:
            if p.zeroDay {
                let pulse = 0.6 + 0.4 * sin(Double(e.elapsed) * 8)
                ctx.fill(Path(roundedRect: r.insetBy(dx: -4, dy: -4), cornerRadius: 6),
                         with: .color(col(1, 0.2, 0.8, pulse * 0.5)))
                fill = col(1.0, 0.3, 0.8); text = .white
            } else {
                ctx.fill(Path(roundedRect: r.insetBy(dx: -3, dy: -3), cornerRadius: 6),
                         with: .color(col(1, 0.25, 0.2, 0.3)))
                fill = col(0.95, 0.28, 0.24); text = .white
            }
        }
        ctx.fill(body, with: .linearGradient(Gradient(colors: [fill, fill.opacity(0.7)]),
                                             startPoint: CGPoint(x: r.minX, y: r.minY),
                                             endPoint: CGPoint(x: r.minX, y: r.maxY)))
        // connector chip on the left
        ctx.fill(Path(roundedRect: CGRect(x: r.minX + 2, y: r.midY - 4, width: 4, height: 8), cornerRadius: 1),
                 with: .color(.black.opacity(0.35)))
        ctx.stroke(body, with: .color(.white.opacity(0.25)), lineWidth: 0.8)
        ctx.draw(Text(p.label).font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(text),
                 at: CGPoint(x: r.midX + 2, y: r.midY))
    }

    private static func drawParticle(_ p: Particle, _ ctx: inout GraphicsContext) {
        let a = Double(max(0, p.life / p.maxLife))
        let c: Color
        switch p.color {
        case .green: c = col(0.3, 1, 0.5, a)
        case .red:   c = col(1, 0.35, 0.25, a)
        case .amber: c = col(1, 0.75, 0.2, a)
        case .white: c = col(1, 1, 1, a)
        case .gold:  c = col(1, 0.85, 0.3, a)
        }
        ctx.fill(circle(p.pos, p.size * CGFloat(0.4 + a)), with: .color(c))
    }

    // MARK: HUD

    private static func drawHUD(_ e: GameEngine, _ ctx: inout GraphicsContext, _ size: CGSize) {
        ctx.draw(Text("\(e.score)").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white),
                 at: CGPoint(x: 7, y: 5), anchor: .topLeading)
        ctx.draw(Text("HI \(e.hiScore)").font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(col(0.3, 1, 0.5, 0.85)), at: CGPoint(x: 8, y: 23), anchor: .topLeading)

        ctx.draw(Text("THREAT LV \(e.threatLevel)").font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(col(1, 0.5, 0.4)), at: CGPoint(x: size.width - 7, y: 6), anchor: .topTrailing)
        if e.combo > 1 {
            ctx.draw(Text("COMBO x\(e.combo)").font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(col(0.3, 1, 0.6)), at: CGPoint(x: size.width - 7, y: 20), anchor: .topTrailing)
        }

        // integrity bar (in the server band)
        let by = e.coreY + 7
        let bw = size.width - 16
        let frac = Double(clamp(e.integrity / 100, 0, 1))
        ctx.fill(Path(roundedRect: CGRect(x: 8, y: by, width: bw, height: 6), cornerRadius: 3),
                 with: .color(col(1, 1, 1, 0.14)))
        ctx.fill(Path(roundedRect: CGRect(x: 8, y: by, width: bw * CGFloat(frac), height: 6), cornerRadius: 3),
                 with: .color(mix((1, 0.25, 0.2), (0.2, 1.0, 0.5), frac)))
        ctx.draw(Text("INTEGRITY \(Int(e.integrity))%").font(.system(size: 7.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.8)), at: CGPoint(x: 9, y: by + 9), anchor: .topLeading)

        // charge / purge bar
        let cy = e.coreY + 25
        ctx.fill(Path(roundedRect: CGRect(x: 8, y: cy, width: bw, height: 3), cornerRadius: 1.5),
                 with: .color(col(1, 1, 1, 0.12)))
        ctx.fill(Path(roundedRect: CGRect(x: 8, y: cy, width: bw * CGFloat(e.charge / 100), height: 3), cornerRadius: 1.5),
                 with: .color(col(0.3, 0.85, 1.0)))
        if e.purgeReady {
            let blink = sin(Double(e.elapsed) * 8) > 0
            ctx.draw(Text("⟳ TURN CROWN: PURGE").font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundStyle(col(0.4, 0.9, 1.0, blink ? 1 : 0.4)),
                     at: CGPoint(x: size.width / 2, y: cy + 8), anchor: .center)
        }

        if e.bannerTimer > 0 {
            let a = Double(min(1, e.bannerTimer / 0.5))
            let isBad = e.bannerText.contains("BREACH") || e.bannerText.contains("FALSE") || e.bannerText.contains("DDoS")
            let c = isBad ? col(1, 0.4, 0.35, a) : col(0.4, 1, 0.6, a)
            ctx.draw(Text(e.bannerText).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(c),
                     at: CGPoint(x: size.width / 2, y: size.height * 0.36), anchor: .center)
        }
    }

    // MARK: Helpers

    private static func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        let u = min(max(t, 0), 1)
        return Color(.sRGB, red: a.0 + (b.0 - a.0) * u, green: a.1 + (b.1 - a.1) * u, blue: a.2 + (b.2 - a.2) * u, opacity: 1)
    }
    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
