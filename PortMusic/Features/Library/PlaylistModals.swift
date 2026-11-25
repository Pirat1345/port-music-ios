import SwiftUI

// MARK: - Create Playlist Sheet ("Neu" Action in Library)
public struct CreatePlaylistSheet: View {
    public let serverURL: String
    public var onCreated: (DiscoveryPlaylist) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isCreating: Bool = false
    @State private var errorText: String? = nil

    public init(serverURL: String, onCreated: @escaping (DiscoveryPlaylist) -> Void) {
        self.serverURL = serverURL
        self.onCreated = onCreated
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name der Playlist")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                        TextField("Meine neue Playlist", text: $title)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beschreibung (optional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                        TextField("Kurze Beschreibung...", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    }

                    if let err = errorText {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Button(action: {
                        Task { await submit() }
                    }) {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text(isCreating ? "Wird erstellt..." : "Playlist erstellen")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.35) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isCreating || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Neue Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func submit() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        errorText = nil
        let token = SessionManager.shared.currentToken

        if let created = await MusicService.shared.createPlaylist(
            title: trimmed,
            description: description,
            serverURL: serverURL,
            token: token
        ) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            await MainActor.run {
                isCreating = false
                onCreated(created)
                dismiss()
            }
        } else {
            await MainActor.run {
                isCreating = false
                errorText = "Playlist konnte nicht erstellt werden. Bitte Anmeldung prüfen."
            }
        }
    }
}

// MARK: - Import Playlist Sheet ("Importieren" Action in Library)
public struct ImportPlaylistSheet: View {
    public let serverURL: String
    public var onImported: (DiscoveryPlaylist) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputUrl: String = ""
    @State private var customTitle: String = ""
    @State private var isLoadingPreview: Bool = false
    @State private var isImporting: Bool = false
    @State private var importProgress: Double = 0
    @State private var preview: PlaylistImportPreview? = nil
    @State private var errorText: String? = nil

    public init(serverURL: String, onImported: @escaping (DiscoveryPlaylist) -> Void) {
        self.serverURL = serverURL
        self.onImported = onImported
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Füge einen Playlist- oder Album-Link von Spotify, Apple Music, Deezer, YouTube Music oder SoundCloud ein.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.60))

                        HStack(spacing: 8) {
                            TextField("https://open.spotify.com/playlist/...", text: $inputUrl)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)

                            Button(action: pasteFromClipboard) {
                                Text("Einfügen")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )

                        Button(action: {
                            Task { await loadPreview() }
                        }) {
                            HStack(spacing: 8) {
                                if isLoadingPreview {
                                    ProgressView().tint(.black)
                                }
                                Text(isLoadingPreview ? "Vorschau wird geladen..." : "Playlist laden")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(inputUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.35) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoadingPreview || inputUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let err = errorText {
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        if let prev = preview {
                            previewCard(prev)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Playlist importieren")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func previewCard(_ prev: PlaylistImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#18181b"))
                        .frame(width: 72, height: 72)

                    PortCachedAsyncImage(url: resolveCoverURL(prev.playlistCover, serverURL: serverURL)) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } placeholder: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 26))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(prev.playlistName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text("\(prev.trackCount) Songs gefunden")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.60))
                    if let owner = prev.playlistOwner, !owner.isEmpty {
                        Text("von \(owner)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.42))
                    }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Ziel-Playlistname")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.55))
                TextField("Titel", text: $customTitle)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if isImporting {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: importProgress)
                        .tint(.white)
                    Text("Songs werden gespeichert (\(Int(importProgress * 100))%)...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                }
            }

            Button(action: {
                Task { await performImport(prev) }
            }) {
                Text(isImporting ? "Importiere..." : "\(prev.trackCount) Songs importieren")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isImporting || prev.tracks.isEmpty)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func pasteFromClipboard() {
        if let str = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
            inputUrl = str
            Task { await loadPreview() }
        }
    }

    private func loadPreview() async {
        let trimmed = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingPreview = true
        errorText = nil
        preview = nil
        let token = SessionManager.shared.currentToken

        let res = await MusicService.shared.previewImportPlaylist(url: trimmed, serverURL: serverURL, token: token)
        await MainActor.run {
            self.isLoadingPreview = false
            if let p = res.preview {
                self.preview = p
                self.customTitle = p.playlistName
            } else {
                self.errorText = res.error ?? "Vorschau fehlgeschlagen."
            }
        }
    }

    private func performImport(_ prev: PlaylistImportPreview) async {
        isImporting = true
        importProgress = 0
        errorText = nil
        let token = SessionManager.shared.currentToken
        let finalTitle = customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? prev.playlistName
            : customTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let created = await MusicService.shared.createPlaylist(
            title: finalTitle,
            description: "Importiert von \(inputUrl)",
            serverURL: serverURL,
            token: token
        ) else {
            await MainActor.run {
                isImporting = false
                errorText = "Ziel-Playlist konnte nicht erstellt werden."
            }
            return
        }

        let convertedTracks = prev.tracks.map { $0.toTrack() }
        let total = max(convertedTracks.count, 1)
        for (idx, tr) in convertedTracks.enumerated() {
            _ = await MusicService.shared.addTrackToPlaylist(
                playlistId: created.id,
                track: tr,
                serverURL: serverURL,
                token: token
            )
            await MainActor.run {
                self.importProgress = Double(idx + 1) / Double(total)
            }
        }

        let enriched = DiscoveryPlaylist(
            id: created.id,
            title: created.title,
            cover: prev.playlistCover ?? created.cover,
            nbTracks: convertedTracks.count,
            user: created.user
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        await MainActor.run {
            isImporting = false
            onImported(enriched)
            dismiss()
        }
    }
}
