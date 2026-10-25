//
//  GateView.swift
//  Port Music
//
//  Clean OLED Dark authentication view adhering to Port Music Design Guidelines.
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
                    // Calm Deep Dark Background (Port Music Design Guidelines)
                    Color.portBackground
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 24) {
                            // Port Music Brand Header
                            VStack(spacing: 12) {
                                Image("PortLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.portBorder, lineWidth: 1)
                                    )
                                    .padding(.top, 28)

                                Text("Port Music")
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .foregroundColor(.white)

                                Text("Online Music & Audio Cloud")
                                    .font(.subheadline)
                                    .foregroundColor(.portTextSecondary)
                            }

                            // Server Address Pill
                            VStack(spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.portBrand)
                                        .font(.caption)

                                    Text(account.serverURL)
                                        .font(.caption)
                                        .foregroundColor(.portTextSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showServerConfig.toggle()
                                        }
                                    } label: {
                                        Text(showServerConfig ? "Schließen" : "Server ändern")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.portBrand)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.portSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.portBorder, lineWidth: 1)
                                EndLine:
                                )
                                .cornerRadius(10)

                                if showServerConfig {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Backend-Adresse (Port Music Server)")
                                            .font(.caption2)
                                            .foregroundColor(.portTextMuted)

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
                                            .foregroundColor(.portBrand)
                                        }
                                        .padding(10)
                                        .background(Color.portSurfaceElevated)
                                        .cornerRadius(8)
                                    }
                                    .padding(12)
                                    .background(Color.portSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.portBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                    .transition(.opacity)
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

                            // Error Notice
                            if let err = localError ?? account.errorMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.red.opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                .cornerRadius(10)
                                .padding(.horizontal, 24)
                            }

                            // Active Form
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
                                Text("Als Gast fortfahren")
                                    .font(.footnote)
                                    .foregroundColor(.portTextMuted)
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 32)
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
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.portTextMuted)
                    TextField("Benutzername", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort")
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.portTextMuted)
                    SecureField("Passwort", text: $password)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            Button {
                submitLogin()
            } label: {
                HStack(spacing: 8) {
                    if account.isLoading {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(account.isLoading ? "Wird angemeldet..." : "Anmelden")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.portBrand)
                .foregroundColor(.black)
                .cornerRadius(12)
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
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.portTextMuted)
                    TextField("z. B. max", text: $registerUsername)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Anzeigename (optional)")
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle.fill")
                        .foregroundColor(.portTextMuted)
                    TextField("z. B. Max Mustermann", text: $registerDisplayName)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("E-Mail")
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.portTextMuted)
                    TextField("name@example.com", text: $registerEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort")
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.portTextMuted)
                    SecureField("Mindestens 6 Zeichen", text: $password)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Passwort wiederholen")
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.portTextMuted)
                    SecureField("Passwort bestätigen", text: $confirmPassword)
                        .foregroundColor(.white)
                }
                .padding(14)
                .background(Color.portSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                .cornerRadius(12)
            }

            Button {
                submitRegister()
            } label: {
                HStack(spacing: 8) {
                    if account.isLoading {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(account.isLoading ? "Konto wird erstellt..." : "Konto erstellen")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.portBrand)
                .foregroundColor(.black)
                .cornerRadius(12)
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
