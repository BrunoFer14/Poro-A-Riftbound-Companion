import SwiftUI

struct ProfileView: View {
    let authService: AuthService
    let syncService: SyncService
    let friendsService: FriendsService
    let cardCache: CardCache

    @State private var showAuth = false
    @State private var showSignOutAlert = false

    private var pendingCount: Int {
        friendsService.friends.filter { $0.status == .pending && !$0.initiator }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if authService.isLoggedIn {
                    loggedInContent
                } else {
                    loggedOutContent
                }
            }
            .navigationTitle("Perfil")
            .sheet(isPresented: $showAuth) {
                AuthView(authService: authService)
            }
            .alert("Terminar sessão?", isPresented: $showSignOutAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Terminar", role: .destructive) {
                    try? authService.signOut()
                }
            } message: {
                Text("Os teus dados locais serão mantidos, mas a sincronização será desativada.")
            }
        }
    }

    private var loggedOutContent: some View {
        ContentUnavailableView {
            Label("Sem sessão iniciada", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text("Inicia sessão para sincronizar a tua coleção e decks entre dispositivos.")
        } actions: {
            Button {
                showAuth = true
            } label: {
                Text("Iniciar sessão")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
    }

    private var loggedInContent: some View {
        List {
            Section("Social") {
                NavigationLink {
                    FriendsView(friendsService: friendsService, cardCache: cardCache, authService: authService)
                } label: {
                    HStack {
                        Label("Amigos", systemImage: "person.2.fill")
                        Spacer()
                        if pendingCount > 0 {
                            Text("\(pendingCount)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.red, in: .capsule)
                        }
                    }
                }
            }

            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 4) {
                        if let name = authService.displayName, !name.isEmpty {
                            Text(name)
                                .font(.headline)
                        }
                        if let email = authService.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    Label("Sincronização", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView()
                    } else if syncService.syncError != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else if syncService.lastSyncDate != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = syncService.syncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let lastSync = syncService.lastSyncDate {
                    HStack {
                        Text("Última sincronização")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lastSync, style: .relative)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task {
                        await syncService.performSync()
                    }
                } label: {
                    Label("Sincronizar agora", systemImage: "arrow.clockwise")
                }
                .disabled(syncService.isSyncing)
            } header: {
                Text("Dados")
            }

            Section("Sobre") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("Política de Privacidade", systemImage: "hand.raised")
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutAlert = true
                } label: {
                    Label("Terminar sessão", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }
}

// MARK: - Auth View (Login / Register)

private struct AuthView: View {
    let authService: AuthService

    @Environment(\.dismiss) private var dismiss
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var resetSent = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Palavra-passe", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)

                    if isRegistering {
                        SecureField("Confirmar palavra-passe", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(isRegistering ? "Criar conta" : "Iniciar sessão")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }

                Section {
                    Button {
                        withAnimation { isRegistering.toggle() }
                        errorMessage = nil
                    } label: {
                        Text(isRegistering ? "Já tenho conta" : "Criar nova conta")
                    }

                    if !isRegistering {
                        Button {
                            resetEmail = email
                            showResetPassword = true
                        } label: {
                            Text("Esqueci a palavra-passe")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle(isRegistering ? "Criar conta" : "Iniciar sessão")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Recuperar palavra-passe", isPresented: $showResetPassword) {
                TextField("Email", text: $resetEmail)
                Button("Enviar") {
                    Task {
                        try? await authService.resetPassword(email: resetEmail)
                        resetSent = true
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Introduz o teu email para receber um link de recuperação.")
            }
            .alert("Email enviado", isPresented: $resetSent) {
                Button("OK") {}
            } message: {
                Text("Verifica a tua caixa de correio para recuperar a palavra-passe.")
            }
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        if isRegistering {
            return emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil

        do {
            if isRegistering {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            errorMessage = mapError(error)
        }

        isLoading = false
    }

    private func mapError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17008: return "Email inválido."
        case 17009: return "Palavra-passe incorreta."
        case 17011: return "Conta não encontrada."
        case 17007: return "Este email já está registado."
        case 17026: return "A palavra-passe deve ter pelo menos 6 caracteres."
        default: return "Erro: \(error.localizedDescription)"
        }
    }
}
