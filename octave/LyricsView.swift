//
//  LyricsView.swift
//  octave
//
//  Time-synced lyrics with karaoke karaoke highlight and translation.
//

import SwiftUI

struct LyricsView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var lyricsService = LyricsService.shared
    @State private var lines: [LyricLine] = []
    @State private var isLoading: Bool = true
    @State private var isTranslated: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading lyrics...")
                        .tint(.white)
                        .foregroundColor(.white)
                } else if lines.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No lyrics available for this song")
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(lines.indices, id: \.self) { idx in
                                    let line = lines[idx]
                                    let isCurrent = isLineActive(line, index: idx)

                                    Text(isTranslated && line.translation != nil ? line.translation! : line.text)
                                        .font(.system(size: isCurrent ? 28 : 22, weight: .bold))
                                        .foregroundColor(isCurrent ? .white : .white.opacity(0.4))
                                        .scaleEffect(isCurrent ? 1.05 : 1.0, anchor: .leading)
                                        .animation(.easeInOut(duration: 0.25), value: isCurrent)
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
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isTranslated.toggle()
                    } label: {
                        Image(systemName: isTranslated ? "translate.fill" : "translate")
                            .foregroundColor(.white)
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
