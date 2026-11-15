import Foundation
import MediaPlayer
import AVFoundation
import Combine

public final class SystemVolumeManager: ObservableObject {
    public static let shared = SystemVolumeManager()

    @Published public var volume: Float = 0.5
    private var volumeSlider: UISlider?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let current = AVAudioSession.sharedInstance().outputVolume
        self.volume = current > 0 ? current : 0.5

        // Hidden MPVolumeView to obtain the system volume slider
        let volumeView = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        volumeView.alpha = 0.0001
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                self.volumeSlider = slider
                break
            }
        }

        // Listen for hardware volume button presses & output volume changes
        NotificationCenter.default.publisher(for: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notif in
                if let vol = notif.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
                    self?.volume = vol
                } else {
                    self?.volume = AVAudioSession.sharedInstance().outputVolume
                }
            }
            .store(in: &cancellables)
    }

    public func syncVolume() {
        self.volume = AVAudioSession.sharedInstance().outputVolume
    }

    public func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        if let slider = volumeSlider {
            slider.value = clamped
            slider.sendActions(for: .valueChanged)
        } else {
            let volumeView = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
            for subview in volumeView.subviews {
                if let slider = subview as? UISlider {
                    self.volumeSlider = slider
                    slider.value = clamped
                    slider.sendActions(for: .valueChanged)
                    break
                }
            }
        }
        AudioPlayerManager.shared.avPlayer?.volume = clamped
    }
}
