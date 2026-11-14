import SwiftUI

public struct ToyItem: Identifiable, Equatable {
    public let id: String
    public let germanName: String

    public static let all: [ToyItem] = [
        ToyItem(id: "duck", germanName: "Ente"),
        ToyItem(id: "bear", germanName: "Bär"),
        ToyItem(id: "panda", germanName: "Panda"),
        ToyItem(id: "bunny", germanName: "Häschen"),
        ToyItem(id: "dino", germanName: "Dino"),
        ToyItem(id: "penguin", germanName: "Pinguin"),
        ToyItem(id: "fox", germanName: "Fuchs"),
        ToyItem(id: "frog", germanName: "Frosch"),
        ToyItem(id: "whale", germanName: "Wal"),
        ToyItem(id: "cat", germanName: "Katze"),
        ToyItem(id: "puppy", germanName: "Welpe"),
        ToyItem(id: "unicorn", germanName: "Einhorn")
    ]
}

public struct CaptchaChallengeSheetView: View {
    public let serverURL: String
    public let challengeToken: String
    public let targetId: String
    public let onSuccess: (String) -> Void
    public let onCancel: () -> Void

    @State private var displayedToys: [ToyItem] = []
    @State private var selectedToy: String? = nil
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isSuccess: Bool = false

    public init(
        serverURL: String,
        challengeToken: String,
        targetId: String,
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.challengeToken = challengeToken
        self.targetId = targetId
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    private var targetItem: ToyItem {
        ToyItem.all.first(where: { $0.id == targetId }) ?? ToyItem(id: targetId, germanName: targetId.capitalized)
    }

    public var body: some View {
        ZStack {
            FluentBackgroundView()

            VStack(spacing: 20) {
                // Obere Leiste mit Schließen-Button
                HStack {
                    Text("Sicherheitsüberprüfung")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)

                    Spacer()

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(PortColors.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Ziel-Vorgabe (Welches Tier soll gefangen werden?)
                VStack(spacing: 8) {
                    Text("Wähle das gesuchte Kuscheltier aus:")
                        .font(.system(size: 14))
                        .foregroundColor(PortColors.textSecondary)

                    HStack(spacing: 12) {
                        if let img = loadToyImage(name: targetItem.id) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("GESUCHTES ZIEL")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(PortColors.accentOrange)

                            Text(targetItem.germanName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PortColors.surfaceGlassStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(PortColors.accentOrange.opacity(0.6), lineWidth: 1.5)
                    )
                }

                // Fehleranzeige
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(PortColors.errorRed)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PortColors.errorRed.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Kuscheltier-Grid zum interaktiven Auswählen
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(displayedToys) { toy in
                            toyButton(toy: toy)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                if isVerifying {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Verifizierung läuft...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PortColors.textSecondary)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupToys()
        }
    }

    private func toyButton(toy: ToyItem) -> some View {
        Button(action: {
            guard !isVerifying && !isSuccess else { return }
            selectToy(toy)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(PortColors.surfaceGlass)
                        .frame(width: 72, height: 72)

                    if let img = loadToyImage(name: toy.id) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    }
                }

                Text(toy.germanName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PortColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(cardBackground(for: toy))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder(for: toy), lineWidth: 1.2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isVerifying || isSuccess)
    }

    private func cardBackground(for toy: ToyItem) -> Color {
        if selectedToy == toy.id {
            if isSuccess {
                return PortColors.successGreen.opacity(0.25)
            } else if errorMessage != nil {
                return PortColors.errorRed.opacity(0.20)
            }
        }
        return PortColors.surfaceGlass
    }

    private func cardBorder(for toy: ToyItem) -> Color {
        if selectedToy == toy.id {
            if isSuccess {
                return PortColors.successGreen
            } else if errorMessage != nil {
                return PortColors.errorRed
            }
        }
        return PortColors.borderGlass
    }

    private func setupToys() {
        var pool = ToyItem.all.filter { $0.id != targetItem.id }
        pool.shuffle()
        // Wähle 5 Distraktoren aus und füge das echte Ziel hinzu
        var selected = Array(pool.prefix(5))
        selected.append(targetItem)
        selected.shuffle()
        displayedToys = selected
    }

    private func selectToy(_ toy: ToyItem) {
        selectedToy = toy.id

        if toy.id != targetItem.id {
            // Falsches Kuscheltier gewählt!
            errorMessage = "Falsches Kuscheltier gewählt! Bitte versuche es erneut."
            // Nach kurzer Zeit Fehler zurücksetzen und neu mischen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                selectedToy = nil
                errorMessage = nil
                setupToys()
            }
            return
        }

        // Richtiges Kuscheltier gewählt! Jetzt an den Server senden
        errorMessage = nil
        isVerifying = true
        isSuccess = true

        Task {
            let res = await AuthService.shared.verifyCaptcha(
                serverURL: serverURL,
                challengeToken: challengeToken,
                target: targetItem.id
            )

            await MainActor.run {
                isVerifying = false
                if res.success, let token = res.token {
                    // Erfolgreich verifiziert!
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSuccess(token)
                    }
                } else {
                    isSuccess = false
                    selectedToy = nil
                    errorMessage = "Server-Verifizierung fehlgeschlagen. Bitte erneut versuchen."
                    setupToys()
                }
            }
        }
    }

    private func loadToyImage(name: String) -> UIImage? {
        if let img = UIImage(named: name) {
            return img
        }
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        return nil
    }
}
