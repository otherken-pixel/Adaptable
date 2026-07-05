import SwiftUI

/// Landing screen for Supabase password-recovery deep links. Mirrors
/// `src/pages/ResetPasswordPage.tsx`.
struct ResetPasswordView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var authStore: AuthStore

    @State private var password = ""
    @State private var confirm = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var done = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Circle().fill(Theme.accentSoft).frame(width: 64, height: 64)
                        .overlay(Image(systemName: "key.fill").font(.system(size: 26)).foregroundStyle(Theme.accent))
                    Text("Set a new password").font(.system(size: 22, weight: .heavy))
                    Text("You're signed in via your recovery link — choose a new password to finish.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .padding(.top, 60)

                if done {
                    Text("Password updated 🎉 Taking you home…")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 12) {
                        SecureField("New password", text: $password)
                            .padding(.horizontal, 16).frame(height: 52)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
                        SecureField("Confirm password", text: $confirm)
                            .padding(.horizontal, 16).frame(height: 52)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.down)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(Theme.surface) }
                                Text("Update password").font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(Theme.surface)
                            .background(Theme.content, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .disabled(busy)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.surface)
    }

    private func submit() async {
        errorMessage = nil
        guard password == confirm else {
            errorMessage = "Passwords don't match."
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await authStore.updatePassword(password)
            done = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
