//
//  TrackListRow.swift
//  Port Music
//

import SwiftUI

struct TrackListRow: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(LibraryIndex.self) private var libraryIndex
    let song: SongEntity
    var onPlay: () -> Void

    private var isCurrentTrack: Bool {
        player.currentTrack?.id == song.id
    }

    private var isSaved: Bool {
        libraryIndex.isSaved(id: song.id)
    }

    private var isDownloaded: Bool {
        DownloadManager.shared.isDownloaded(id: song.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tippbarer Wiedergabebereich (Artwork + Titel/Kuenstler)
            HStack(spacing: 12) {
                ArtworkView(urlString: song.artworkURLString)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if isCurrentTrack && player.isPlaying {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundColor(.portBrand)
                        }
                        Text(song.title)
                            .font(.body)
                            .fontWeight(isCurrentTrack ? .bold : .medium)
                            .foregroundColor(isCurrentTrack ? .portBrand : .white)
                            .lineLimit(1)

                        if isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.portBrand)
                                .accessibilityLabel("Heruntergeladen")
                        }
                    }

                    Text(song.artist)
                        .font(.caption)
                        .foregroundColor(.portTextSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onPlay)

            // Aktionen-Bereich (Favorit-Button + Menue)
            HStack(spacing: 4) {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    Task {
                        await libraryIndex.toggle(song: song)
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isSaved ? Color(red: 252/255, green: 60/255, blue: 68/255) : .white.opacity(0.35))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")

                Menu {
                    Button {
                        Task { await libraryIndex.toggle(song: song) }
                    } label: {
                        Label(
                            isSaved ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen",
                            systemImage: isSaved ? "heart.fill" : "heart"
                        )
                    }
                    Button {
                        Task {
                            if isDownloaded {
                                DownloadManager.shared.removeDownload(trackId: song.id)
                            } else {
                                try? await DownloadManager.shared.download(song: song)
                            }
                        }
                    } label: {
                        Label(
                            isDownloaded ? "Download entfernen" : "Herunterladen",
                            systemImage: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle"
                        )
                    }
                    Button("Als Nächstes abspielen") {
                        SongVerbs.playNext(song: song)
                    }
                    Button("Zur Playlist hinzufügen", action: {})
                    Button("Titel teilen", action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.portTextMuted)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .contextMenu {
            Button {
                Task { await libraryIndex.toggle(song: song) }
            } label: {
                Label(
                    isSaved ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen",
                    systemImage: isSaved ? "heart.fill" : "heart"
                )
            }
            Button {
                Task {
                    if isDownloaded {
                        DownloadManager.shared.removeDownload(trackId: song.id)
                    } else {
                        try? await DownloadManager.shared.download(song: song)
                    }
                }
            } label: {
                Label(
                    isDownloaded ? "Download entfernen" : "Herunterladen",
                    systemImage: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle"
                )
            }
            Button("Als Nächstes abspielen") {
                SongVerbs.playNext(song: song)
            }
            Button("Zur Playlist hinzufügen", action: {})
            Button("Titel teilen", action: {})
        }
    }
}
