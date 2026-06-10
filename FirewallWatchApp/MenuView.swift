import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var engine: GameEngine
    private let green = Color(.sRGB, red: 0.25, green: 1.0, blue: 0.5, opacity: 1)

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 30))
                .foregroundStyle(green)
                .padding(.bottom, 2)

            Text("FIREWALL")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("DEFEND THE CORE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(green.opacity(0.7))

            if engine.hiScore > 0 {
                Text("HI \(engine.hiScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 3)
            }

            Button {
                Haptic.uiTap()
                engine.start()
            } label: {
                Text("ENGAGE")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(green)
            .padding(.top, 7)

            Text("Tap malware · let traffic pass")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 3)
        }
        .padding(.horizontal, 14)
    }
}
