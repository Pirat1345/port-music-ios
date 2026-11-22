import SwiftUI

public struct DeviceDtoItem: Codable, Identifiable {
    public let id: String
    public let deviceName: String
    public let deviceModel: String?
    public let os: String?
    public let browser: String?
    public let ipAddress: String?
    public let lastSeen: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case deviceName
        case deviceModel
        case os
        case browser
        case ipAddress
        case lastSeen
    }
}

public struct DeviceManagementView: View {
    @State private var devices: [DeviceDtoItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var deviceToDelete: DeviceDtoItem? = nil

    private var serverURL: String {
        ServerProfileManager.shared.activeServerURL.isEmpty
            ? (SessionManager.shared.serverURL ?? "")
            : ServerProfileManager.shared.activeServerURL
    }

    private var token: String? {
        SessionManager.shared.currentToken
    }

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading && devices.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, devices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Button("Erneut versuchen") {
                        Task { await loadDevices() }
                    }
                    .foregroundColor(.blue)
                }
                .padding()
            } else {
                List {
                    Section(
                        header: Text("Angemeldete Geräte").foregroundColor(.gray),
                        footer: Text("Hier siehst du alle Geräte und Browser-Sitzungen, die mit deinem Port Music Konto verknüpft sind. Du kannst Sitzungen per Wischgeste oder Menü aus der Ferne beenden.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    ) {
                        ForEach(devices) { dev in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(deviceIconColor(for: dev))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: deviceIconName(for: dev))
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(dev.deviceName.isEmpty ? "Unbekanntes Gerät" : dev.deviceName)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)

                                        if isCurrentDevice(dev) {
                                            Text("DIESES GERÄT")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.20))
                                                .foregroundColor(.green)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    HStack(spacing: 6) {
                                        if let os = dev.os, !os.isEmpty {
                                            Text(os)
                                        }
                                        if let browser = dev.browser, !browser.isEmpty {
                                            Text("·")
                                            Text(browser)
                                        }
                                        if let ip = dev.ipAddress, !ip.isEmpty {
                                            Text("·")
                                            Text(ip)
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)

                                    Text(formattedLastSeen(dev.lastSeen))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.40))
                                }

                                Spacer()

                                if !isCurrentDevice(dev) {
                                    Button(role: .destructive) {
                                        deviceToDelete = dev
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red.opacity(0.80))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isCurrentDevice(dev) {
                                    Button(role: .destructive) {
                                        deviceToDelete = dev
                                    } label: {
                                        Label("Abmelden", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.10))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Geräte & Sitzungen")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task {
            await loadDevices()
        }
        .refreshable {
            await loadDevices()
        }
        .alert("Sitzung beenden?", isPresented: Binding(
            get: { deviceToDelete != nil },
            set: { if !$0 { deviceToDelete = nil } }
        )) {
            Button("Abbrechen", role: .cancel) {
                deviceToDelete = nil
            }
            Button("Abmelden", role: .destructive) {
                if let target = deviceToDelete {
                    Task { await revokeDevice(target) }
                }
            }
        } message: {
            if let dev = deviceToDelete {
                Text("Möchtest du das Gerät '\(dev.deviceName)' wirklich abmelden? Die Sitzung wird sofort ungültig.")
            }
        }
    }

    private func isCurrentDevice(_ dev: DeviceDtoItem) -> Bool {
        let currentModel = UIDevice.current.model
        if let model = dev.deviceModel, model.lowercased().contains(currentModel.lowercased()) {
            return true
        }
        if dev.deviceName.lowercased().contains("ios") || dev.deviceName.lowercased().contains("iphone") {
            return true
        }
        return false
    }

    private func deviceIconName(for dev: DeviceDtoItem) -> String {
        let os = (dev.os ?? "").lowercased()
        let name = dev.deviceName.lowercased()
        if os.contains("ios") || name.contains("iphone") {
            return "iphone"
        } else if os.contains("ipad") || name.contains("ipad") {
            return "ipad"
        } else if os.contains("mac") || name.contains("mac") {
            return "laptopcomputer"
        } else if os.contains("windows") || name.contains("win") {
            return "desktopcomputer"
        } else if os.contains("android") {
            return "phone.fill"
        }
        return "display"
    }

    private func deviceIconColor(for dev: DeviceDtoItem) -> Color {
        let os = (dev.os ?? "").lowercased()
        if os.contains("ios") || os.contains("mac") {
            return .blue
        } else if os.contains("windows") {
            return .cyan
        } else if os.contains("android") {
            return .green
        }
        return .indigo
    }

    private func formattedLastSeen(_ epochMs: Int64) -> String {
        guard epochMs > 0 else { return "Zuletzt aktiv: Unbekannt" }
        let date = Date(timeIntervalSince1970: TimeInterval(epochMs / 1000))
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .full
        return "Aktiv " + formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(base)/api/devices") else {
            isLoading = false
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                let decoded = try JSONDecoder().decode([DeviceDtoItem].self, from: data)
                await MainActor.run {
                    self.devices = decoded
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Geräte konnten nicht geladen werden"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Verbindungsfehler zum Server"
                self.isLoading = false
            }
        }
    }

    private func revokeDevice(_ target: DeviceDtoItem) async {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let safeId = target.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target.id
        guard let url = URL(string: "\(base)/api/devices/\(safeId)") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                await MainActor.run {
                    self.devices.removeAll(where: { $0.id == target.id })
                    self.deviceToDelete = nil
                }
            }
        } catch {}
    }
}
