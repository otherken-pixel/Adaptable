import SwiftUI

private enum AuthMode { case signIn, signUp, forgot }

/// Sign in / sign up / forgot password + Google OAuth. Mirrors
/// `src/pages/AuthPage.tsx`.
struct AuthView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var notice: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.heroGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: Theme.accent.opacity(0.25), radius: 20, y: 8)
                        .overlay(Image(systemName: "fork.knife").font(.system(size: 32, weight: .semibold)).foregroundStyle(.white))
                        .floating
                    Text("Adaptable").font(.system(size: 30, weight: .heavy)).padding(.top, 8)
                    Text("AI recipes that adapt to you. Generate, cook, vote.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    if mode == .signUp {
                        AuthField(label: "Username", text: $username, placeholder: "chef_you")
                    }
                    AuthField(label: "Email", text: $email, placeholder: "you@example.com", keyboard: .emailAddress)
                    if mode != .forgot {
                        AuthField(label: "Password", text: $password, placeholder: "••••••••", isSecure: true)
                    }
                    if mode == .signIn {
                        HStack {
                            Spacer()
                            Button("Forgot password?") {
                                mode = .forgot; errorMessage = nil; notice = nil
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.down)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.down.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if let notice {
                        Text(notice)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if busy { ProgressView().tint(Theme.surface) }
                            Text(mode == .signIn ? "Sign in" : mode == .signUp ? "Create account" : "Send reset link")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(Theme.surface)
                        .background(Theme.content, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .opacity(busy ? 0.5 : 1)
                    }
                    .buttonStyle(.pressable)
                    .disabled(busy)
                }

                if mode != .forgot {
                    HStack(spacing: 12) {
                        Rectangle().fill(Theme.line).frame(height: 1)
                        Text("or").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }

                    Button {
                        Task { await google() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill").foregroundStyle(.red)
                            Text("Continue with Google").font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(Theme.content)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
                    }
                    .buttonStyle(.pressable)
                }

                Button {
                    mode = mode == .signIn ? .signUp : .signIn
                    errorMessage = nil; notice = nil
                } label: {
                    Group {
                        switch mode {
                        case .signIn:
                            Text("New here? ").foregroundStyle(Theme.muted) + Text("Create an account").foregroundStyle(Theme.accent)
                        case .signUp:
                            Text("Already cooking? ").foregroundStyle(Theme.muted) + Text("Sign in").foregroundStyle(Theme.accent)
                        case .forgot:
                            Text("Remembered it? ").foregroundStyle(Theme.muted) + Text("Back to sign in").foregroundStyle(Theme.accent)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.surface)
    }

    private func submit() async {
        busy = true; errorMessage = nil; notice = nil
        defer { busy = false }
        do {
            switch mode {
            case .signIn:
                try await authStore.signInWithPassword(email: email, password: password)
            case .signUp:
                try await authStore.signUp(email: email, password: password, username: username)
                notice = "Check your inbox to confirm your email, then sign in."
            case .forgot:
                try await authStore.requestPasswordReset(email: email)
                notice = "Reset link sent — check your inbox."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func google() async {
        errorMessage = nil
        do {
            try await authStore.signInWithGoogle()
        } catch {
            errorMessage = "Google sign-in failed."
        }
    }
}

private struct AuthField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.muted)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 15))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        }
    }
}
