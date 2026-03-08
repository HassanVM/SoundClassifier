// HapticService.swift
// Uniform haptic feedback — identical pulse for all categories and intensities.
// Uses kSystemSoundID_Vibrate which is the strongest vibration available to third-party apps.
// Note: Incoming call vibration is system-privileged and cannot be matched by any public API.

import UIKit
import AudioToolbox

final class HapticService {

    static let shared = HapticService()

    private var isEnabled: Bool = true
    private var lastFireTime: CFTimeInterval = 0
    private let minimumInterval: CFTimeInterval = 0.5

    private init() {}

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Fire a uniform haptic pulse. Strongest available vibration for third-party apps.
    func fireUniformPulse() {
        guard isEnabled else { return }

        let now = CACurrentMediaTime()
        guard (now - lastFireTime) >= minimumInterval else { return }
        lastFireTime = now

        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    /// Legacy API — calls uniform pulse regardless of category.
    func fireHaptic(for category: SoundCategory) {
        fireUniformPulse()
    }
}
