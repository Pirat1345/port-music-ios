//
//  SettingsView.swift
//  octave
//

import SwiftUI

struct SettingsView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var presenter = SettingsPresenter()

    var body: some View {
        Form {
            Section("Audio Playback") {
                Toggle("Gapless Playback", isOn: Binding(
                    get: { player.gaplessEnabled },
                    set: { player.gaplessEnabled = $0 }
                ))

                Toggle("Spatial Audio", isOn: Binding(
                    get: { player.spatialAudio },
                    set: { player.spatialAudio = $0 }
                ))

                Picker("Automix Mode", selection: Binding(
                    get: { player.automixStyle },
                    set: { player.automixStyle = $0 }
                )) {
                    Text("Off").tag(AudioPlayer.AutomixStyle.off)
                    Text("Smooth Crossfade").tag(AudioPlayer.AutomixStyle.smooth)
                    Text("Beat-Matched").tag(AudioPlayer.AutomixStyle.beatmatch)
                }

                if player.automixStyle != .off {
                    Stepper("Crossfade: \(Int(player.crossfadeSeconds))s", value: Binding(
                        get: { player.crossfadeSeconds },
                        set: { player.crossfadeSeconds = $0 }
                    ), in: 1...15)
                }
            }

            Section("Streaming & Downloads") {
                Picker("Audio Streaming Quality", selection: $presenter.streamingQuality) {
                    Text("Normal (128 kbps)").tag("128")
                    Text("High (256 kbps)").tag("256")
                    Text("Maximum (320 kbps / Lossless)").tag("320")
                }

                Toggle("Download Over Cellular", isOn: $presenter.allowCellularDownloads)
            }
        }
        .navigationTitle("Playback Settings")
    }
}
