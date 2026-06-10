import SwiftUI

struct GameOverView: View {
    @EnvironmentObject private var engine: GameEngine
    private var isHigh: Bool { engine.score > 0 && engine.score >= engine.hiScore }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 3) {
                Text("SYSTEM BREACHED")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(.sRGB, red: 1, green: 0.35, blue: 0.3, opacity: 1))

                Text("\(engine.score)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if isHigh {
                    Text("★ NEW HIGH SCORE ★")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(.sRGB, red: 0.3, green: 1, blue: 0.5, opacity: 1))
                } else {
                    Text("HI \(engine.hiScore)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text("reached threat level \(engine.threatLevel)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 8) {
                    Button { Haptic.uiTap(); engine.backToMenu() } label: {
                        Image(systemName: "house.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button { Haptic.uiTap(); engine.start() } label: {
                        Image(systemName: "arrow.clockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(.sRGB, red: 0.25, green: 1, blue: 0.5, opacity: 1))
                }
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
        }
    }
}
