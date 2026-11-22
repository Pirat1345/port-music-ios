import SwiftUI

public struct ServerManagementView: View {
    @ObservedObject private var profileManager = ServerProfileManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddServerSheet: Bool = false
    @State private var newServerName: String = ""
    @State private var newServerURL: String = "http://"
    @State private var isTestingNewServer: Bool = false
    @State private var testResultText: String? = nil
    @State private var testSuccess: Bool? = nil

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                // Sektion 1: Gespeicherte Server
                Section(header: Text("Gespeicherte Server").foregroundColor(.gray)) {
                    ForEach(profileManager.profiles) { profile in
                        let isActive = profile.url.lowercased() == profileManager.activeServerURL.lowercased()

                        Button(action: {
                            if !isActive {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                profileManager.switchServer(to: profile)
                            }
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isActive ? Color.blue.opacity(0.20) : Color.white.opacity(0.08))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "server.rack")
                                        .foregroundColor(isActive ? .blue : .white.opacity(0.80))
                                        .font(.system(size: 16))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(profile.url)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                if isActive {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let profile = profileManager.profiles[idx]
                            if profile.url.lowercased() != profileManager.activeServerURL.lowercased() {
                                profileManager.removeProfile(id: profile.id)
                            }
                        }
                    }
                }
                .listRowBackground(Color(white: 0.10))

                // Sektion 2: Neuer Server
                Section {
                    Button(action: {
                        newServerName = ""
                        newServerURL = "http://"
                        testResultText = nil
                        testSuccess = nil
                        showAddServerSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            Text("Neuen Server hinzufügen...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowBackground(Color(white: 0.10))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Server verwalten")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddServerSheet) {
            addServerSheetContent
        }
    }

    private var addServerSheetContent: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section(header: Text("Server-Details").foregroundColor(.gray)) {
                        TextField("Name (z. B. Heimnetzwerk)", text: $newServerName)
                            .foregroundColor(.white)
                        TextField("Server-URL (z. B. http://192.168.178.19:8090)", text: $newServerURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color(white: 0.12))

                    Section {
                        Button(action: {
                            Task {
                                isTestingNewServer = true
                                testResultText = nil
                                let (reachable, ms) = await profileManager.testConnection(url: newServerURL)
                                isTestingNewServer = false
                                testSuccess = reachable
                                if reachable {
                                    testResultText = "Verbindung erfolgreich (\(ms ?? 0) ms)"
                                } else {
                                    testResultText = "Server nicht erreichbar"
                                }
                            }
                        }) {
                            HStack {
                                Text("Verbindung prüfen")
                                Spacer()
                                if isTestingNewServer {
                                    ProgressView().tint(.white)
                                } else if let success = testSuccess {
                                    Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(success ? .green : .red)
                                }
                            }
                        }

                        if let res = testResultText {
                            Text(res)
                                .font(.system(size: 13))
                                .foregroundColor(testSuccess == true ? .green : .red)
                        }
                    }
                    .listRowBackground(Color(white: 0.12))

                    Section {
                        Button("Server speichern und verbinden") {
                            let name = newServerName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let finalName = name.isEmpty ? "Server" : name
                            profileManager.addOrUpdateProfile(name: finalName, url: newServerURL)

                            if let created = profileManager.profiles.first(where: { $0.url.lowercased() == newServerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).lowercased() }) {
                                profileManager.switchServer(to: created)
                            }

                            showAddServerSheet = false
                            dismiss()
                        }
                        .disabled(newServerURL.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                        .foregroundColor(.blue)
                    }
                    .listRowBackground(Color(white: 0.12))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Neuer Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        showAddServerSheet = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
