import Foundation
import Supabase

/// Session + profile state, sign in/up/out, password reset, taste
/// preferences and account deletion. Mirrors `src/context/AuthContext.tsx`.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var loading: Bool
    /// Non-nil when we have a session but profile fetch failed (soft fail).
    @Published private(set) var profileLoadError: String?
    /// True when signed in at the auth layer even if profile is temporarily missing.
    @Published private(set) var hasSession = false

    let isDemo = SupabaseManager.isDemo
    private var authTask: Task<Void, Never>?
    private var lastUserId: String?

    init() {
        if isDemo {
            profile = Profile(
                id: DemoStore.demoUser.id,
                username: DemoStore.demoUser.username,
                avatar_url: nil,
                preferences: nil,
                created_at: DemoStore.demoUser.created_at
            )
            hasSession = true
            loading = false
        } else {
            loading = true
        }
    }

    func start() {
        guard !isDemo, authTask == nil else { return }
        authTask = Task { [weak self] in
            guard let self else { return }
            if let session = try? await SupabaseManager.client.auth.session {
                self.hasSession = true
                self.lastUserId = session.user.id.uuidString
                await self.loadProfile(userId: session.user.id.uuidString)
            } else {
                self.hasSession = false
                self.loading = false
            }
            for await (_, session) in SupabaseManager.client.auth.authStateChanges {
                if let session {
                    self.hasSession = true
                    self.lastUserId = session.user.id.uuidString
                    await self.loadProfile(userId: session.user.id.uuidString)
                } else {
                    self.hasSession = false
                    self.lastUserId = nil
                    self.profile = nil
                    self.profileLoadError = nil
                    self.loading = false
                }
            }
        }
    }

    /// Re-reads the demo preferences (call after Demo Mode mutations).
    func refreshDemoPreferences() {
        guard isDemo else { return }
        Task {
            let prefs = DemoStore.shared.getPreferences()
            self.profile?.preferences = prefs
        }
    }

    /// Retry profile load after a soft failure (network blip).
    func retryProfileLoad() async {
        guard let userId = lastUserId else { return }
        loading = true
        await loadProfile(userId: userId)
    }

    private func loadProfile(userId: String) async {
        do {
            let rows: [Profile] = try await SupabaseManager.client
                .from("profiles").select("*").eq("id", value: userId).limit(1).execute().value
            if let row = rows.first {
                self.profile = row
                self.profileLoadError = nil
            } else {
                // Session valid but profile row missing — keep session, show retry.
                if self.profile?.id != userId {
                    self.profile = nil
                }
                self.profileLoadError = "Couldn't load your profile. Check your connection and try again."
            }
        } catch {
            print("[AuthStore] profile load failed: \(error)")
            // Soft fail: keep existing profile if we already had one for this user.
            if self.profile?.id == userId {
                self.profileLoadError = "Couldn't refresh your profile — using cached data."
            } else {
                self.profile = nil
                self.profileLoadError = AppError.friendlyMessage(for: error)
            }
        }
        self.loading = false
    }

    // MARK: - Auth actions

    func signInWithPassword(email: String, password: String) async throws {
        try await SupabaseManager.client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, username: String) async throws {
        try await SupabaseManager.client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)]
        )
    }

    func signInWithGoogle() async throws {
        try await SupabaseManager.client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseManager.redirectURL
        )
    }

    func signOut() async {
        guard !isDemo else { return }
        // Unregister push before clearing session so the API still has a user.
        PushManager.shared.setCurrentUser(nil)
        try? await SupabaseManager.client.auth.signOut()
    }

    func requestPasswordReset(email: String) async throws {
        guard !isDemo else { return }
        try await SupabaseManager.client.auth.resetPasswordForEmail(
            email, redirectTo: SupabaseManager.resetPasswordRedirectURL
        )
    }

    func updatePassword(_ newPassword: String) async throws {
        guard !isDemo else { return }
        try await SupabaseManager.client.auth.update(user: UserAttributes(password: newPassword))
    }

    func updateUsername(_ username: String) async throws {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 && clean.count <= 24 else {
            throw AppError("Username must be 3–24 characters.")
        }
        if isDemo {
            profile?.username = clean
            return
        }
        guard let profile else { return }
        do {
            struct Payload: Encodable { let username: String }
            try await SupabaseManager.client.from("profiles")
                .update(Payload(username: clean)).eq("id", value: profile.id).execute()
            self.profile?.username = clean
        } catch let error as PostgrestError {
            throw AppError(error.code == "23505" ? "That username is taken." : error.message)
        }
    }

    func updatePreferences(_ prefs: Preferences) async throws {
        if isDemo {
            DemoStore.shared.setPreferences(prefs)
            profile?.preferences = prefs
            return
        }
        guard let profile else { return }
        struct Payload: Encodable { let preferences: Preferences }
        try await SupabaseManager.client.from("profiles")
            .update(Payload(preferences: prefs)).eq("id", value: profile.id).execute()
        self.profile?.preferences = prefs
    }

    func setAvatarUrl(_ url: String) {
        profile?.avatar_url = url
    }

    func deleteAccount() async throws {
        guard !isDemo else { return }
        try await API.deleteAccount()
        PushManager.shared.setCurrentUser(nil)
        try? await SupabaseManager.client.auth.signOut()
    }
}
