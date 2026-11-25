import SwiftUI

public struct EditProfileView: View {
    public let user: UserProfile
    public let serverURL: String

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessBanner: Bool = false

    public init(user: UserProfile, serverURL: String) {
        self.user = user
        self.serverURL = serverURL
        _displayName = State(initialValue: user.displayName ?? user.username)
        _email = State(initialValue: user.email ?? "")
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                Section(header: Text("Profilinformationen").foregroundColor(.gray)) {
                    HStack {
                        Text("Benutzername")
                            .foregroundColor(.gray)
                            .frame(width: 120, alignment: .leading)
                        Text(user.username)
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text("Anzeigename")
                            .foregroundColor(.gray)
                            .frame(width: 120, alignment: .leading)
                        TextField("Name eingeben", text: $displayName)
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text("E-Mail")
                            .foregroundColor(.gray)
                            .frame(width: 120, alignment: .leading)
                        TextField("E-Mail eingeben", text: $email)
                            .foregroundColor(.white)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }
                .listRowBackground(Color(white: 0.10))

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    .listRowBackground(Color(white: 0.10))
                }

                Section {
                    Button(action: {
                        Task { await saveProfile() }
                    }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Änderungen speichern")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
                .listRowBackground(Color(white: 0.10))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Profil bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert("Profil gespeichert", isPresented: $showSuccessBanner) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Deine Profildaten wurden erfolgreich aktualisiert.")
        }
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(base)/api/auth/profile") else {
            isSaving = false
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = SessionManager.shared.currentToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var payload: [String: String] = [:]
        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["displayName"] = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["email"] = email.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            isSaving = false
            return
        }
        req.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            if (200...299).contains(statusCode) {
                // Lokales UserProfile im SessionManager aktualisieren
                let updated = UserProfile(
                    id: user.id,
                    username: user.username,
                    email: email.isEmpty ? user.email : email,
                    role: user.role,
                    createdAt: user.createdAt,
                    avatar: user.avatar,
                    displayName: displayName.isEmpty ? user.displayName : displayName
                )
                await MainActor.run {
                    SessionManager.shared.currentUser = updated
                    self.isSaving = false
                    self.showSuccessBanner = true
                }
            } else {
                let err = String(data: data, encoding: .utf8) ?? "Profil konnte nicht aktualisiert werden"
                await MainActor.run {
                    self.errorMessage = err
                    self.isSaving = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Verbindungsfehler zum Server"
                self.isSaving = false
            }
        }
    }
}
