//
//  ServerConfigurationView.swift
//  Port Music
//
//  Dedizierte Server-URL-Konfigurationsansicht mit Verbindungstest
//  und nahtlosem Übergang zum Anmelde-Bildschirm.
//

import SwiftUI

enum ServerConnectionStatus: Equatable {
    case idle
    case testing
    case reachable(latencyMs: Int?)
    case unreachable(reason: String)
}

struct ServerConfigurationView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    var onSaved: (() -> Void)? = nil

    @State private var serverAddress: String = ""
    @State private var status: ServerConnectionStatus = .idle
    @State private var localError: String? = nil

    var body: some View {
        ZStack {
            // OLED Deep Black Background
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    headerSection

                    // Input Mask Card
                    inputSection

                    // Connection Test Card & Badge
                    connectionTestSection

                    // Information / Port Hint Card
                    infoSection

                    // Save & Transition Action
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Server-Konfiguration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    dismiss()
                }
                .foregroundColor(.portTextSecondary)
            }
        }
        .onAppear {
            if serverAddress.isEmpty {
                serverAddress = account.serverURL
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.portSurface)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.portBorder, lineWidth: 1)
                    )

                Image(systemName: "server.rack")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.portBrand)
            }
            .padding(.top, 8)

            Text("Backend-Verbindung")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Geben Sie die Adresse Ihres Port Music Servers an, um auf Ihre Musiksammlung und Online-Dienste zuzugreifen.")
                .font(.footnote)
                .foregroundColor(.portTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server-Adresse")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.portTextSecondary)

            HStack(spacing: 10) {
                Image(systemName: "network")
                    .foregroundColor(.portTextMuted)
                    .font(.subheadline)

                TextField("http://192.168.178.19:3000", text: $serverAddress)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .onChange(of: serverAddress) { _, _ in
                        status = .idle
                        localError = nil
                    }

                if !serverAddress.isEmpty {
                    Button {
                        serverAddress = ""
                        status = .idle
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.portTextMuted)
                            .font(.subheadline)
                    }
                }
            }
            .padding(14)
            .background(Color.portSurfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(localError != nil ? Color.red.opacity(0.6) : Color.portBorder, lineWidth: 1)
            )
            .cornerRadius(12)

            if let err = localError {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
        .padding(16)
        .background(Color.portSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.portBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Verbindungsstatus")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.portTextSecondary)

                Spacer()

                statusBadge
            }

            Button {
                Task {
                    await runConnectionTest()
                }
            } label: {
                HStack(spacing: 8) {
                    if status == .testing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.caption)
                    }
                    Text(status == .testing ? "Wird geprüft..." : "Verbindung testen")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.portSurfaceElevated)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.portBorder, lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .disabled(status == .testing || serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
        .padding(16)
        .background(Color.portSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.portBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .idle:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.portTextMuted)
                    .frame(width: 8, height: 8)
                Text("Nicht geprüft")
                    .font(.caption)
                    .foregroundColor(.portTextMuted)
            }
        case .testing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.portBrand)
                Text("Prüfen...")
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
            }
        case .reachable(let latency):
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.portBrand)
                    .frame(width: 8, height: 8)
                Text("Erreichbar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.portBrand)
                if let lat = latency {
                    Text("(\(lat) ms)")
                        .font(.caption2)
                        .foregroundColor(.portTextMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.portBrand.opacity(0.12))
            .clipShape(Capsule())
        case .unreachable(let reason):
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Nicht erreichbar")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())

                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.portTextMuted)
                    .font(.caption)
                Text("Hinweise zur Konfiguration")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.portTextSecondary)
            }

            Text("Geben Sie das Protokoll (http:// oder https://), die IP-Adresse oder Domäne sowie den Port Ihres Port Music Servers an. Standardmäßig verwendet der Server Port 3000.")
                .font(.caption2)
                .foregroundColor(.portTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portSurface.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.portBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var actionSection: some View {
        Button {
            saveAndProceed()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)
                Text("Speichern & Anmelden")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(Color.portBrand)
            .foregroundColor(.black)
            .cornerRadius(14)
        }
        .disabled(serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
        .padding(.top, 4)
    }

    // MARK: - Logic & Actions

    static func normalizeURL(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        if clean.isEmpty {
            return ""
        }
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "http://" + clean
        }
        if clean.lowercased().hasSuffix("/api") {
            clean = String(clean.dropLast(4))
            while clean.hasSuffix("/") {
                clean.removeLast()
            }
        }
        return clean
    }

    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host,
              !host.isEmpty,
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            return false
        }
        return true
    }

    private func runConnectionTest() async {
        localError = nil
        let normalized = Self.normalizeURL(serverAddress)
        guard Self.isValidURL(normalized) else {
            localError = "Bitte geben Sie eine gültige Server-Adresse ein."
            status = .unreachable(reason: "Ungültige URL")
            return
        }

        serverAddress = normalized
        status = .testing

        guard let baseURL = URL(string: normalized) else {
            status = .unreachable(reason: "Ungültiges Format")
            return
        }

        let endpoint = baseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("status")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 5.0
        let testSession = URLSession(configuration: sessionConfig)

        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await testSession.data(for: request)
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            guard let httpRes = response as? HTTPURLResponse else {
                status = .unreachable(reason: "Keine HTTP-Antwort")
                return
            }

            if (200...299).contains(httpRes.statusCode) {
                status = .reachable(latencyMs: latencyMs)
            } else {
                status = .unreachable(reason: "HTTP-Fehler \(httpRes.statusCode)")
            }
        } catch {
            let desc = error.localizedDescription
            if desc.lowercased().contains("timed out") || desc.lowercased().contains("zeitüberschreitung") {
                status = .unreachable(reason: "Zeitüberschreitung (Timeout)")
            } else {
                status = .unreachable(reason: "Keine Verbindung zum Server")
            }
        }
    }

    private func saveAndProceed() {
        let normalized = Self.normalizeURL(serverAddress)
        guard Self.isValidURL(normalized) else {
            localError = "Bitte geben Sie eine gültige Server-Adresse ein."
            return
        }

        // 1. Persist normalized URL in AccountStore / OctaveBackend
        account.updateServerURL(normalized)

        // 2. Invalidate existing auth session
        account.signOut()

        // 3. Callback to set GateView mode to .login
        onSaved?()

        // 4. Dismiss configuration view
        dismiss()
    }
}
