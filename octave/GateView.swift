//
//  GateView.swift
//  octave
//

import SwiftUI

enum AuthMode: Int, CaseIterable, Identifiable {
    case login = 0
    case register = 1

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .login: return "Anmelden"
        case .register: return "Registrieren"
        }
    }
}

struct GateView<Content: View>: View {
    @Environment(AccountStore.self) private var account
    @ViewBuilder let content: () -> Content

    @State private var mode: AuthMode = .login
    @State private var identifier: String = ""
    @State private var registerUsername: String = ""
    @State private var registerEmail: String = ""
    @State private var registerDisplayName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    @State private var serverURL: String = ""
    @State private var showServerConfig: Bool = false
    @State private var localError: String?

    var body: some View {
        if account.isAuthenticated {
            content()
        } else {
            NavigationStack {
                ZStack {
                    // Modern Octave Dark Gradient Backdrop
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.05, blue: 0.14),
                            Color(red: 0.04, green: 0.04, blue: 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    // Ambient glow rings
                    Circle()
                        .fill(Color.purple.opacity(0.18))
                        .blur(radius: 80)
                        .offset(x: -100, y: -200)

                    Circle()
                        .fill(Color.pink.opacity(0.12))
                        .blur(radius: 90)
                        .offset(x: 120, y: 150)

                    ScrollView {
                        VStack(spacing: 24) {
                            // App Branding
                            VStack(spacing: 8) {
                                Image(systemName: "music.note.house.fill")
                                    .font(.system(size: 54, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.pink, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .padding(.top, 24)

                                Text("Octave")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(.white)

                                Text("Port-Music Backend Cloud")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.65))
                            }

                            // Server Address Indicator & Editor
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text(account.serverURL)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        withAnimation(.spring) {
                                            showServerConfig.toggle()
                                        }
                                    } label: {
                                        Text(showServerConfig ? "Schließen" : "Server ändern")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)

                                if showServerConfig {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Backend-Adresse (Port-Music)")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                        HStack {
                                            TextField("http://192.168.178.19:3000", text: $serverURL)
                                                .textInputAutocapitalization(.never)
                                                .disableAutocorrection(true)
                                                .foregroundColor(.white)
                                                .font(.subheadline)
                                            Button("Speichern") {
                                                account.updateServerURL(serverURL)
                                                withAnimation { showServerConfig = false }
                                            }
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                        }
                                        .padding(10)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(8)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.horizontal, 24)

                            // Auth Mode Picker (Anmelden / Registrieren)
                            Picker("Modus", selection: $mode) {
                                ForEach(AuthMode.allCases) { item in
                                    Text(item.title).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 24)

                            // Error Box
                            if let err = localError ?? account.errorMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            }

                            // Forms
                            if mode == .login {
                                loginForm
                            } else {
                                registerForm
                            }

                            // Guest Mode fallback
                            Button {
                                account.username = "Gast-Hörer"
                                account.displayName = "Gast"
                                account.isAuthenticated = true
                            } label: {
                                Text("Als Gast fortfahren (Offline/Test)")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .onAppear {
                self.serverURL = account.serverURL
            }
        }
    }

    // MARK: - Login Form View

    private var loginForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Benutzername oder E-Mail")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.purple)
                    TextField("Benutzername", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.purple)
                    SecureField("Passwort", text: $password)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            Button {
                submitLogin()
            } label: {
                HStack(spacing: 8) {
                    if account.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(account.isLoading ? "Wird angemeldet..." : "Anmelden")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: .purple.opacity(0.4), radius: 10, y: 4)
            }
            .disabled(account.isLoading || identifier.isEmpty || password.isEmpty)
            .opacity((identifier.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Register Form View

    private var registerForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Benutzername")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.pink)
                    TextField("z. B. max", text: $registerUsername)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Anzeigename (optional)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "person.text.rectangle.fill")
                        .foregroundColor(.pink)
                    TextField("z. B. Max Mustermann", text: $registerDisplayName)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("E-Mail")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.pink)
                    TextField("name@example.com", text: $registerEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.pink)
                    SecureField("Mindestens 6 Zeichen", text: $password)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort wiederholen")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.pink)
                    SecureField("Passwort bestätigen", text: $confirmPassword)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            Button {
                submitRegister()
            } label: {
                HStack(spacing: 8) {
                    if account.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(account.isLoading ? "Konto wird erstellt..." : "Konto erstellen")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: .pink.opacity(0.4), radius: 10, y: 4)
            }
            .disabled(account.isLoading || registerUsername.isEmpty || registerEmail.isEmpty || password.isEmpty)
            .opacity((registerUsername.isEmpty || registerEmail.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    private func submitLogin() {
        localError = nil
        Task {
            _ = await account.login(identifier: identifier, password: password)
        }
    }

    private func submitRegister() {
        localError = nil
        guard password == confirmPassword else {
            localError = "Die Passwörter stimmen nicht überein."
            return
        }
        Task {
            _ = await account.register(
                username: registerUsername,
                email: registerEmail,
                password: password,
                displayName: registerDisplayName.isEmpty ? nil : registerDisplayName
            )
        }
    }
}
