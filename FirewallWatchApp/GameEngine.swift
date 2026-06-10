import SwiftUI

/// The Firewall simulation. `@Published` drives the menu/game-over UI; the hot
/// per-frame state is `private(set)` and advanced once per display refresh by
/// the `TimelineView` in `GamePlayView`. The renderer only reads it.
@MainActor
final class GameEngine: ObservableObject {

    @Published private(set) var phase: GamePhase = .menu
    @Published private(set) var score = 0
    @Published private(set) var hiScore = 0

    // Per-frame state (renderer reads)
    private(set) var screen = CGSize(width: 184, height: 224)
    private(set) var integrity: CGFloat = 100
    private(set) var combo = 0
    private(set) var charge: CGFloat = 0
    private(set) var purgeReady = false
    private(set) var threatLevel = 1
    private(set) var packets: [Packet] = []
    private(set) var particles: [Particle] = []
    private(set) var elapsed: CGFloat = 0
    private(set) var flashGood: CGFloat = 0
    private(set) var flashBad: CGFloat = 0
    private(set) var shake: CGFloat = 0
    private(set) var ddosWarn: CGFloat = 0
    private(set) var bannerText = ""
    private(set) var bannerTimer: CGFloat = 0

    var coreY: CGFloat { screen.height * 0.82 }

    // Bookkeeping
    private var spawnAccum: CGFloat = 0
    private var ddosTimer: CGFloat = 26
    private var ddosPending = false
    private var idSeq = 0
    private var lastLevel = 1
    private var lastDate: Date?
    private var ending = false
    private var pendingDemo: String?
    private let hiKey = "Firewall.hiScore"

    init() {
        hiScore = UserDefaults.standard.integer(forKey: hiKey)
        #if DEBUG
        configureLaunchDemo()
        #endif
    }

    // MARK: Lifecycle

    func start() {
        phase = .playing
        ending = false
        score = 0; integrity = 100; combo = 0; charge = 0; purgeReady = false
        threatLevel = 1; lastLevel = 1
        packets.removeAll(); particles.removeAll()
        elapsed = 0; flashGood = 0; flashBad = 0; shake = 0; ddosWarn = 0
        spawnAccum = 0.6; ddosTimer = 26; ddosPending = false
        bannerTimer = 0; lastDate = nil
        banner("DEFEND")
    }

    func backToMenu() { phase = .menu }

    // MARK: Input

    /// Tap a packet to block it. Threats → blocked (good). Legit → false positive.
    func tap(at pt: CGPoint) {
        guard phase == .playing else { return }
        let pad: CGFloat = 9
        let hits = packets.indices.filter { packets[$0].rect().insetBy(dx: -pad, dy: -pad).contains(pt) }
        guard let idx = hits.max(by: { packets[$0].pos.y < packets[$1].pos.y }) else { return }
        let p = packets[idx]
        packets.remove(at: idx)
        if p.kind == .threat { blockThreat(p) } else { falsePositive(p) }
    }

    /// Turn the Crown when charged → quarantine sweep.
    func tryPurge() {
        guard phase == .playing, purgeReady else { return }
        purgeReady = false
        charge = 0
        flashGood = 0.8
        shake = max(shake, 6)
        banner("PURGE")
        Haptic.purge()
        for p in packets where p.kind == .threat {
            addScore(p.zeroDay ? 250 : 100)
            spawnBurst(p.pos, .green, 8)
        }
        packets.removeAll { $0.kind == .threat }
    }

    // MARK: Step

    func advance(to date: Date, size: CGSize) {
        guard phase == .playing else { lastDate = date; return }
        screen = size
        #if DEBUG
        if pendingDemo != nil { applyPendingDemo() }
        #endif
        let dt = min(CGFloat(date.timeIntervalSince(lastDate ?? date)), 1.0 / 20.0)
        lastDate = date
        guard dt > 0 else { return }

        elapsed += dt
        flashGood = max(0, flashGood - dt * 2)
        flashBad = max(0, flashBad - dt * 1.8)
        shake = max(0, shake - dt * 36)
        bannerTimer = max(0, bannerTimer - dt)
        if ddosWarn > 0 {
            ddosWarn -= dt
            if ddosWarn <= 0 && ddosPending { ddosPending = false; spawnFlood() }
        }

        threatLevel = 1 + Int(elapsed / 18)
        if threatLevel > lastLevel { lastLevel = threatLevel; banner("THREAT LV \(threatLevel)"); Haptic.levelUp() }

        purgeReady = charge >= 100

        updateSpawns(dt)
        updatePackets(dt)
        updateParticles(dt)
    }

    // MARK: Spawning

    private func updateSpawns(_ dt: CGFloat) {
        spawnAccum -= dt
        if spawnAccum <= 0 {
            packets.append(makePacket(forceThreat: false))
            let interval = clamp(1.05 - elapsed * 0.006, 0.32, 1.05)
            spawnAccum = interval * CGFloat.random(in: 0.8...1.2)
        }
        ddosTimer -= dt
        if ddosTimer <= 0 && ddosWarn <= 0 {
            ddosWarn = 1.3
            ddosPending = true
            ddosTimer = CGFloat.random(in: 24...36)
        }
    }

    private func makePacket(forceThreat: Bool) -> Packet {
        let ratio = clamp(0.42 + elapsed * 0.0025, 0.42, 0.78)
        let isThreat = forceThreat || Double.random(in: 0...1) < Double(ratio)
        let zeroDay = isThreat && elapsed > 28 && Double.random(in: 0...1) < 0.12
        let label = zeroDay ? "0-DAY" : (isThreat ? PacketLabels.threats.randomElement()!
                                                   : PacketLabels.legit.randomElement()!)
        let w: CGFloat = 46, h: CGFloat = 18
        let x = CGFloat.random(in: w / 2 + 4 ... screen.width - w / 2 - 4)
        let base = 24 + elapsed * 0.5 + CGFloat(threatLevel) * 2
        let speed = (zeroDay ? base * 1.7 : base) * CGFloat.random(in: 0.85...1.15)
        return Packet(id: nextId(), label: label, kind: isThreat ? .threat : .legit,
                      zeroDay: zeroDay, pos: CGPoint(x: x, y: -12), speed: speed,
                      size: CGSize(width: w, height: h))
    }

    private func spawnFlood() {
        let n = Int.random(in: 5...8)
        for i in 0..<n {
            var p = makePacket(forceThreat: true)
            p.pos = CGPoint(x: CGFloat.random(in: 27...(screen.width - 27)), y: -12 - CGFloat(i) * 24)
            packets.append(p)
        }
        banner("⚠ DDoS")
        Haptic.charged()
    }

    // MARK: Packets

    private func updatePackets(_ dt: CGFloat) {
        for i in packets.indices { packets[i].pos.y += packets[i].speed * dt }
        var remaining: [Packet] = []
        remaining.reserveCapacity(packets.count)
        for p in packets {
            if p.pos.y >= coreY {
                if p.kind == .threat { breach(p) } else { serve(p) }
            } else {
                remaining.append(p)
            }
        }
        packets = remaining
    }

    private func blockThreat(_ p: Packet) {
        combo += 1
        addScore(p.zeroDay ? 250 : 100)
        let wasReady = charge >= 100
        charge = min(100, charge + (p.zeroDay ? 22 : 12))
        if charge >= 100 && !wasReady { Haptic.charged() }
        spawnBurst(p.pos, .green, p.zeroDay ? 14 : 9)
        Haptic.block()
    }

    private func falsePositive(_ p: Packet) {
        combo = 0
        addScore(-40)
        integrity = max(0, integrity - 4)
        flashBad = 0.55
        shake = max(shake, 5)
        banner("FALSE POSITIVE")
        spawnBurst(p.pos, .amber, 8)
        Haptic.falsePositive()
        if integrity <= 0 { gameOver() }
    }

    private func breach(_ p: Packet) {
        combo = 0
        integrity = max(0, integrity - 18)
        flashBad = 0.9
        shake = max(shake, 12)
        banner("BREACH")
        spawnBurst(CGPoint(x: p.pos.x, y: coreY), .red, 16)
        Haptic.breach()
        if integrity <= 0 { gameOver() }
    }

    private func serve(_ p: Packet) {
        combo += 1
        addScore(8)
        charge = min(100, charge + 3)
        integrity = min(100, integrity + 0.6)   // healthy traffic keeps the firewall warm
        spawnBurst(CGPoint(x: p.pos.x, y: coreY), .green, 3)
    }

    // MARK: Helpers

    private func addScore(_ base: Int) {
        if base > 0 {
            let mult = 1 + CGFloat(min(combo, 40)) * 0.08
            score = max(0, score + Int(CGFloat(base) * mult))
        } else {
            score = max(0, score + base)
        }
    }

    private func banner(_ text: String) { bannerText = text; bannerTimer = 1.4 }

    func spawnBurst(_ at: CGPoint, _ color: FxColor, _ n: Int) {
        for _ in 0..<n {
            let a = Double.random(in: 0...(.pi * 2))
            let s = CGFloat.random(in: 28...130)
            particles.append(Particle(pos: at,
                                      vel: CGVector(dx: CGFloat(cos(a)) * s, dy: CGFloat(sin(a)) * s),
                                      life: .random(in: 0.3...0.6), maxLife: 0.6,
                                      size: .random(in: 1.5...3.2), color: color))
        }
    }

    private func updateParticles(_ dt: CGFloat) {
        for i in particles.indices {
            particles[i].pos.x += particles[i].vel.dx * dt
            particles[i].pos.y += particles[i].vel.dy * dt
            particles[i].vel.dx *= 0.9
            particles[i].vel.dy *= 0.9
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    private func gameOver() {
        guard !ending else { return }
        ending = true
        if score > hiScore { hiScore = score; UserDefaults.standard.set(hiScore, forKey: hiKey) }
        Haptic.gameOver()
        DispatchQueue.main.async { [weak self] in self?.phase = .gameOver }
    }

    private func nextId() -> Int { idSeq += 1; return idSeq }
}

#if DEBUG
extension GameEngine {
    /// Jump into a representative state for screenshots/QA via `FW_DEMO`.
    /// Compiled out of Release builds.
    func configureLaunchDemo() {
        guard let mode = ProcessInfo.processInfo.environment["FW_DEMO"] else { return }
        switch mode {
        case "play":
            phase = .playing
            pendingDemo = mode
        case "over":
            score = 24_180
            hiScore = max(hiScore, 24_180)
            threatLevel = 6
            phase = .gameOver
        default:
            break
        }
    }

    func applyPendingDemo() {
        guard pendingDemo != nil else { return }
        pendingDemo = nil
        ending = false
        score = 7_640; hiScore = max(hiScore, 11_280); integrity = 68; combo = 9; threatLevel = 3
        lastLevel = threatLevel   // suppress the level-up banner for the screenshot
        charge = 100; purgeReady = true
        elapsed = 40
        packets.removeAll(); particles.removeAll()
        let w: CGFloat = 46, h: CGFloat = 18
        func add(_ label: String, _ kind: PacketKind, _ x: CGFloat, _ y: CGFloat, zero: Bool = false) {
            packets.append(Packet(id: nextId(), label: label, kind: kind, zeroDay: zero,
                                  pos: CGPoint(x: screen.width * x, y: screen.height * y),
                                  speed: 40, size: CGSize(width: w, height: h)))
        }
        add("TROJAN", .threat, 0.28, 0.30)
        add("HTTPS", .legit, 0.66, 0.22)
        add("RANSOM", .threat, 0.52, 0.46)
        add("DNS", .legit, 0.22, 0.56)
        add("0-DAY", .threat, 0.78, 0.40, zero: true)
        add("SSH", .legit, 0.42, 0.66)
        spawnBurst(CGPoint(x: screen.width * 0.5, y: screen.height * 0.5), .green, 12)
    }
}
#endif
