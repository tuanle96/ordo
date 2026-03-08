import SwiftUI

struct LoginView: View {
    private enum Field: Hashable {
        case backendBaseURL
        case odooURL
        case database
        case username
        case password
    }

    @Environment(AppState.self) private var appState
    @FocusState private var focusedField: Field?
    @State private var draft = LoginDraft(
        backendBaseURL: "",
        odooURL: "",
        database: "",
        username: "",
        password: ""
    )
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showAdvanced = false

    private var canSubmit: Bool {
        !draft.backendBaseURL.isEmpty
            && !draft.odooURL.isEmpty
            && !draft.database.isEmpty
            && !draft.username.isEmpty
            && !draft.password.isEmpty
            && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Branding Header
                Section {
                    VStack(spacing: OrdoSpacing.lg) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(OrdoColors.accent)
                            .symbolEffect(.pulse, options: .repeating.speed(0.5))

                        VStack(spacing: OrdoSpacing.xs) {
                            Text("Ordo")
                                .font(OrdoTypography.largeTitle)

                            Text("Your Odoo, Native")
                                .font(OrdoTypography.subheadline)
                                .foregroundStyle(OrdoColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OrdoSpacing.lg)
                    .listRowBackground(Color.clear)
                }

                // MARK: - Server
                Section {
                    TextField("Odoo URL", text: $draft.odooURL)
                        .accessibilityIdentifier("login-odoo-url-field")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .odooURL)
                        .submitLabel(.next)

                    TextField("Database", text: $draft.database)
                        .accessibilityIdentifier("login-database-field")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .database)
                        .submitLabel(.next)
                } header: {
                    Text("Server")
                }

                // MARK: - Account
                Section {
                    TextField("Username", text: $draft.username)
                        .accessibilityIdentifier("login-username-field")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)

                    SecureField("Password", text: $draft.password)
                        .accessibilityIdentifier("login-password-field")
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                } header: {
                    Text("Account")
                }

                // MARK: - Advanced (Collapsible)
                Section {
                    DisclosureGroup("Advanced Settings", isExpanded: $showAdvanced) {
                        TextField("Backend API URL", text: $draft.backendBaseURL)
                            .accessibilityIdentifier("login-backend-url-field")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .backendBaseURL)
                            .submitLabel(.done)
                    }
                } footer: {
                    if showAdvanced {
                        Text("Example: \(AppConfig.fallbackBaseURL)")
                    }
                }

                // MARK: - Error
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(OrdoColors.danger)
                            .accessibilityIdentifier("login-error-message")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .accessibilityIdentifier("login-screen")
            .navigationTitle("Sign In")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: submit) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSubmitting ? "Signing In…" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(OrdoColors.accent)
                .accessibilityIdentifier("login-submit-button")
                .controlSize(.large)
                .disabled(!canSubmit)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(.bar)
            }
            .onAppear {
                draft = appState.loginPrefill
                errorMessage = appState.statusMessage
            }
            .onSubmit {
                switch focusedField {
                case .odooURL: focusedField = .database
                case .database: focusedField = .username
                case .username: focusedField = .password
                case .password: submit()
                case .backendBaseURL: focusedField = .odooURL
                case nil: break
                }
            }
            .animation(.smooth, value: errorMessage != nil)
        }
    }

    private func submit() {
        guard canSubmit else { return }

        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                try await appState.signIn(with: draft)
                await MainActor.run {
                    draft.password = ""
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
    .environment(AppState.preview)
}
