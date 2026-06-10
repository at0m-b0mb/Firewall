import WatchKit

/// Taptic feedback by intent. Serving legit traffic is silent (it happens
/// constantly); the impactful security events each get a distinct tap.
enum Haptic {
    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    static func block()         { play(.click) }
    static func breach()        { play(.failure) }
    static func falsePositive() { play(.directionDown) }
    static func purge()         { play(.success) }
    static func charged()       { play(.directionUp) }
    static func levelUp()       { play(.notification) }
    static func gameOver()      { play(.failure) }
    static func uiTap()         { play(.click) }
}
