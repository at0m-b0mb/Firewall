import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject private var engine: GameEngine

    /// Digital Crown is the "system scan" trigger — turning it when the charge
    /// meter is full unleashes a quarantine purge.
    @State private var crown: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                engine.advance(to: timeline.date, size: size)
                FirewallRenderer.draw(engine: engine, context: &context, size: size)
            }
        }
        .background(Color.black)
        .focusable(true)
        .digitalCrownRotation(
            $crown,
            from: 0, through: 100, by: 1,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crown) { _, _ in engine.tryPurge() }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in engine.tap(at: value.location) }
        )
        .ignoresSafeArea()
    }
}
