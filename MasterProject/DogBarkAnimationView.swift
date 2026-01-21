import SwiftUI


struct DogBarkAnimationView: View {
    let pulseID: Int

    @State private var bark = false
    @State private var showWaves = false

    @State private var playToken = UUID()

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let baseSize: CGFloat = min(96, h * 0.72)

            ZStack {
                // Dog always visible
                Image(systemName: "dog")
                    .font(.system(size: baseSize, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .scaleEffect(bark ? 1.12 : 1.0)
                    .rotationEffect(.degrees(bark ? -9 : 0))
                    .offset(y: bark ? -7 : 0)
                    .animation(.spring(response: 0.16, dampingFraction: 0.55), value: bark)

                // Bark waves (only when barking)
                Image(systemName: "wave.3.right")
                    .font(.system(size: baseSize * 0.70, weight: .regular))
                    .offset(x: baseSize * 1.2,
                            y: -baseSize * 0.45)
                    .opacity(showWaves ? 1 : 0)
                    .scaleEffect(showWaves ? 1.0 : 0.75)
                    .animation(.easeOut(duration: 0.22), value: showWaves)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 160)
        .onChange(of: pulseID) { _, _ in
            playDoubleBark()
        }
        .accessibilityLabel("Dog barking")
    }

    private func playDoubleBark() {
        let token = UUID()
        playToken = token

        // FIRST BARK
        bark = true
        showWaves = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard playToken == token else { return }
            bark = false
            showWaves = false
        }

        // SECOND BARK
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard playToken == token else { return }
            bark = true
            showWaves = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard playToken == token else { return }
            bark = false
            showWaves = false
        }
    }
}
