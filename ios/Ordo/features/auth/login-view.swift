import SwiftUI

struct LoginView: View {
    private enum Field: Hashable {
        case backendBaseURL
        case odooURL
        case database
        case username
        case password
    }

    @EnvironmentObject private var appState: AppState
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
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back")
                            .font(.title2.weight(.semibold))
                        Text("Sign in with your middleware URL and Odoo credentials.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    TextField("Backend API URL", text: $draft.backendBaseURL)
                        .accessibilityIdentifier("login-backend-url-field")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .backendBaseURL)
                        .submitLabel(.next)
                } header: {
                    Text("Middleware")
                } footer: {
                    Text("Example: \(AppConfig.fallbackBaseURL)")
                }

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

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
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
                case .backendBaseURL: focusedField = .odooURL
                case .odooURL: focusedField = .database
                case .database: focusedField = .username
                case .username: focusedField = .password
                case .password: submit()
                case nil: break
                }
            }
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
        .environmentObject(AppState.preview)
}
