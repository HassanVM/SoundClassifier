import SwiftUI

struct AlarmAnimationView: View {

    let pulseID: Int

    @State private var visible = false
    @State private var playToken = UUID()

    @State private var bounceTrigger = false

    var body: some View {

        ZStack {

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )

            Image(systemName: "light.beacon.max.fill")
                .font(.system(size: 92, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: bounceTrigger)
                .opacity(visible ? 1 : 0)
                .scaleEffect(visible ? 1.0 : 0.85)
                .animation(.easeOut(duration: 0.12), value: visible)
        }
        .frame(height: 190)
        .onChange(of: pulseID) { _, _ in
            playAlarmSequence()
        }
        .accessibilityLabel("Alarm")
    }

    // MARK: - Animation control

    private func playAlarmSequence() {

        let token = UUID()
        playToken = token

        visible = true
        bounceTrigger = false

        let cycle: TimeInterval = 0.30
        let repeats = 3

        for i in 0..<repeats {

            let t = TimeInterval(i) * cycle

            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard playToken == token else { return }
                bounceTrigger.toggle()
            }
        }

        // Stay visible after animation
        let total = TimeInterval(repeats) * cycle
        let linger: TimeInterval = 1.2

        DispatchQueue.main.asyncAfter(deadline: .now() + total + linger) {
            guard playToken == token else { return }
            visible = false
        }
    }
}
