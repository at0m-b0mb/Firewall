import CoreGraphics

enum GamePhase {
    case menu
    case playing
    case gameOver
}

enum PacketKind {
    case legit    // good traffic — let it reach the core
    case threat   // malware — tap to block before it lands
}

struct Packet {
    let id: Int
    var label: String
    var kind: PacketKind
    var zeroDay: Bool          // fast, high-value threat
    var pos: CGPoint
    var speed: CGFloat         // downward px/sec
    var size: CGSize

    func rect() -> CGRect {
        CGRect(x: pos.x - size.width / 2, y: pos.y - size.height / 2,
               width: size.width, height: size.height)
    }
}

enum FxColor { case green, red, amber, white, gold }

struct Particle {
    var pos: CGPoint
    var vel: CGVector
    var life: CGFloat
    var maxLife: CGFloat
    var size: CGFloat
    var color: FxColor
}

enum PacketLabels {
    static let threats = ["TROJAN", "WORM", "RANSOM", "SPYWARE", "BOTNET", "ROOTKIT",
                          "EXPLOIT", "MALWARE", "KEYLOG", "BACKDOOR", "RAT", "C2"]
    static let legit   = ["HTTP", "HTTPS", "DNS", "SSH", "TLS", "SMTP",
                          "NTP", "API", "GET", "ACK", "SYN", "VPN"]
}

@inline(__always) func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }

extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }
}
