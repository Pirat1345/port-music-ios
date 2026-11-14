//
//  SettingsView.swift
//  octave
//

import SwiftUI

struct SettingsView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var presenter = SettingsPresenter()
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        Form {
            Section("Server & Verbindung") {
                NavigationLink(destination: ServerConfigurationView()) {
                    HStack {
                        Text("Server-Adresse")
                        Spacer()
                        Text(OctaveBackend.shared.serverBaseURLString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section("Audiowiedergabe") {
                Toggle("Nahtlose Wiedergabe (Gapless)", isOn: Binding(
                    get: { player.gaplessEnabled },
                    set: { player.gaplessEnabled = $0 }
                ))

                Toggle("3D-Audio / Spatial Audio", isOn: Binding(
                    get: { player.spatialAudio },
                    set: { player.spatialAudio = $0 }
                ))

                Picker("Automix-Modus", selection: Binding(
                    get: { player.automixStyle },
                    set: { player.automixStyle = $0 }
                )) {
                    Text("Aus").tag(AudioPlayer.AutomixStyle.off)
                    Text("Sanftes Überblenden").tag(AudioPlayer.AutomixStyle.smooth)
                    Text("Beat-Synchronisiert").tag(AudioPlayer.AutomixStyle.beatmatch)
                }

                if player.automixStyle != .off {
                    Stepper("Überblendung: \(Int(player.crossfadeSeconds))s", value: Binding(
                        get: { player.crossfadeSeconds },
                        set: { player.crossfadeSeconds = $0 }
                    ), in: 1...15)
                }
            }

            Section("Streaming & Downloads") {
                Picker("Streaming-Qualität", selection: $presenter.streamingQuality) {
                    Text("Normal (128 kbit/s)").tag("128")
                    Text("Hoch (256 kbit/s)").tag("256")
                    Text("Maximum (320 kbit/s / Verlustfrei)").tag("320")
                }

                Toggle("Downloads über Mobilfunk (Cellular)", isOn: $presenter.allowCellularDownloads)
            }

            Section("Downloads & Speicher") {
                HStack {
                    Text("Heruntergeladene Titel")
                    Spacer()
                    Text("\(DownloadManager.shared.downloadedTrackIds.count)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Speicherbelegung")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: DownloadManager.shared.totalStorageBytes, countStyle: .file))
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Alle Downloads löschen")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .disabled(DownloadManager.shared.downloadedTrackIds.isEmpty && DownloadManager.shared.totalStorageBytes == 0)
            }
        }
        .navigationTitle("Einstellungen")
        .alert("Downloads löschen?", isPresented: $showDeleteConfirm) {
            Button("Löschen", role: .destructive) {
                DownloadManager.shared.clearAllDownloads()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Möchtest du wirklich alle heruntergeladenen Titel und Playlists vom Gerät entfernen?")
        }
    }
}
