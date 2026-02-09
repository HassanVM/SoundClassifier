// HapticService.swift
// CREATE NEW FILE: Right-click MasterProject folder → New File → Swift File → "HapticService"

import UIKit

final class HapticService {

    static let shared = HapticService()

    private var isEnabled: Bool = true

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() { prepareAll() }

    func setEnabled(_ enabled: Bool) { isEnabled = enabled }

    /// Fire haptic for a sound category.
    /// Level is determined by CATEGORY only, NOT by routine/urgent intensity.
    func fireHaptic(for category: SoundCategory) {
        guard isEnabled else { return }
        switch category.hapticLevel {
        case .light: lightGenerator.impactOccurred()
        case .medium: mediumGenerator.impactOccurred()
        case .heavy: heavyGenerator.impactOccurred()
        }
        prepareAll()
    }

    func fireNotification(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }

    private func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
    }
}
