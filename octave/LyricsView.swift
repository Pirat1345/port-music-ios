//
//  LyricsView.swift
//  Port Music
//
//  Time-synced lyrics with karaoke highlight and translation.
//

import SwiftUI

struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var player
    @State private var lyricsService = LyricsService.shared
    @State private var lines: [LyricLine] = []
    @State private var isLoading: Bool = true
    @State private var isTranslated: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.portBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView("Songtext wird geladen...")
                        .tint(.portBrand)
                        .foregroundColor(.white)
                } else if lines.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.portTextMuted)
                        Text("Kein Songtext für diesen Titel verfügbar")
                            .foregroundColor(.portTextSecondary)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                ForEach(lines.indices, id: \.self) { idx in
                                    let line = lines[idx]
                                    let isCurrent = isLineActive(line, index: idx)

                                    Text(isTranslated && line.translation != nil ? line.translation! : line.text)
                                        .font(.system(size: isCurrent ? 28 : 22, weight: isCurrent ? .bold : .medium))
                                        .foregroundColor(isCurrent ? .white : .white.opacity(0.35))
                                        .scaleEffect(isCurrent ? 1.04 : 1.0, anchor: .leading)
                                        .animation(.easeInOut(duration: 0.2), value: isCurrent)
                                        .id(idx)
                                        .onTapGesture {
                                            player.seek(to: line.time)
                                        }
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 40)
                        }
                        .onChange(of: player.currentTime) { _, newTime in
                            if let activeIdx = lines.firstIndex(where: { line in
                                abs(line.time - newTime) < 1.5
                            }) {
                                withAnimation {
                                    proxy.scrollTo(activeIdx, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Songtext")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isTranslated.toggle()
                    } label: {
                        Image(systemName: isTranslated ? "translate.fill" : "translate")
                            .foregroundColor(isTranslated ? .portBrand : .white)
                    }
                }
            }
            .task {
                await loadLyrics()
            }
        }
    }

    private func isLineActive(_ line: LyricLine, index: Int) -> Bool {
        let current = player.currentTime
        let nextTime = index + 1 < lines.count ? lines[index + 1].time : player.duration
        return current >= line.time && current < nextTime
    }

    private func loadLyrics() async {
        guard let song = player.currentTrack else { return }
        isLoading = true
        lines = await lyricsService.fetchLyrics(for: song.id)
        isLoading = false
    }
}
