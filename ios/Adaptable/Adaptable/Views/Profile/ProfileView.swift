import SwiftUI
import PhotosUI

/// Mirrors `src/pages/ProfilePage.tsx`: avatar, stats, username edit, taste
/// profile link, push toggle, sign out, delete account.
struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var push = PushManager.shared

    @State private var mine: [Recipe] = []
    @State private var editing = false
    @State private var draftUsername = ""
    @State private var savingName = false
    @State private var nameError: String?

    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    @State private var avatarBusy = false
    @State private var avatarPickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let profile = authStore.profile {
                    identityCard(profile)
                    statsRow
                    if !mine.isEmpty {
                        creationsSection
                    } else {
                        emptyCreations
                    }
                    tasteProfileLink(profile)
                    pushSection
                    if !authStore.isDemo {
                        signOutButton
                        dangerZone
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .refreshable { await loadMine() }
        .task { await loadMine() }
        .task { await push.refreshAuthorizationStatus() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PROFILE").font(.system(size: 12, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.accent)
            Text("You").font(.system(size: 32, weight: .heavy))
        }
        .padding(.top, 16)
    }

    private func identityCard(_ profile: Profile) -> some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                AuthorAvatar(username: profile.username ?? "anonymous", size: 64, url: profile.avatar_url)
                if !authStore.isDemo {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        Image(systemName: avatarBusy ? "ellipsis" : "camera.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.surface)
                            .frame(width: 26, height: 26)
                            .background(Theme.content, in: Circle())
                            .overlay(Circle().stroke(Theme.raised, lineWidth: 2))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if editing {
                    HStack(spacing: 8) {
                        TextField("Username", text: $draftUsername)
                            .font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12))
                        Button { Task { await saveUsername() } } label: {
                            Image(systemName: savingName ? "ellipsis" : "checkmark")
                                .frame(width: 36, height: 36).background(Theme.accent, in: Circle()).foregroundStyle(.white)
                        }
                        Button { editing = false; nameError = nil } label: {
                            Image(systemName: "xmark").frame(width: 36, height: 36).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                        }
                    }
                    if let nameError {
                        Text(nameError).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.down)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text("@\(profile.username ?? "anonymous")").font(.system(size: 18, weight: .heavy)).lineLimit(1)
                        Button {
                            draftUsername = profile.username ?? ""
                            editing = true
                        } label: {
                            Image(systemName: "pencil").font(.system(size: 11)).frame(width: 28, height: 28).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Text(authStore.isDemo ? "Demo chef — data stays on this device" : "Adaptable chef")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
        }
        .padding(20)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        .onChange(of: avatarPickerItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(item) }
        }
    }

    private var statsRow: some View {
        let totalUpvotes = mine.reduce(0) { $0 + max(0, $1.net_upvotes ?? 0) }
        return HStack(spacing: 12) {
            StatCard(icon: "fork.knife", iconColor: Theme.accent, value: "\(mine.count)", label: "Recipes created")
            StatCard(icon: "arrowshape.up.fill", iconColor: Theme.up, value: Format.compactCount(totalUpvotes), label: "Upvotes earned")
        }
    }

    private var creationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your creations").font(.system(size: 18, weight: .heavy))
            LazyVStack(spacing: 16) {
                ForEach(Array(mine.enumerated()), id: \.element.id) { i, r in RecipeCardView(recipe: r, index: i) }
            }
        }
    }

    private var emptyCreations: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(Theme.accent)
            Text("No creations yet").font(.system(size: 14, weight: .semibold))
            Text("Head to Create and describe your dream meal — your recipes will show up here.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.line, style: StrokeStyle(dash: [5])))
    }

    private func tasteProfileLink(_ profile: Profile) -> some View {
        NavigationLink(value: Route.tasteProfile) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Taste Profile").font(.system(size: 15, weight: .heavy))
                    Text(profile.preferences?.summary ?? Preferences.empty.summary)
                        .font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.faint)
            }
            .padding(20)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        }
        .buttonStyle(.plain)
    }

    private var pushSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: push.status == .enabled ? "bell.badge.fill" : "bell").foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text("Push notifications").font(.system(size: 15, weight: .heavy))
                Text(pushDescription).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if push.status != .enabled {
                Button {
                    Task { await push.requestAuthorization() }
                } label: {
                    Text(push.status == .working ? "…" : "Enable")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.surface)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.content, in: Capsule())
                }
                .disabled(push.status == .working)
            }
        }
        .padding(20)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
    }

    private var pushDescription: String {
        switch push.status {
        case .enabled: return "You're set — Supabase pings APNs directly when your recipes get votes, comments and cooks."
        case .denied: return "Permission was declined — enable notifications for Adaptable in system settings, then try again."
        default: return "Get pinged when your recipes earn votes, comments and cooks."
        }
    }

    private var signOutButton: some View {
        Button {
            Task { await authStore.signOut() }
        } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundStyle(Theme.content)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        }
        .buttonStyle(.pressable)
    }

    private var dangerZone: some View {
        VStack(spacing: 12) {
            if !confirmDelete {
                Button {
                    confirmDelete = true
                } label: {
                    Label("Delete account", systemImage: "trash").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.down)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            } else {
                Text("Permanently delete your account?").font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.center)
                Text("Your recipes, votes, saves, comments and groceries will be erased. This cannot be undone.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                if let deleteError {
                    Text(deleteError).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.down)
                }
                HStack(spacing: 8) {
                    Button("Keep my account") { confirmDelete = false }
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
                    Button {
                        Task { await deleteAccount() }
                    } label: {
                        HStack(spacing: 6) {
                            if deleting { ProgressView().tint(.white) }
                            Text("Delete forever").font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .foregroundStyle(.white)
                        .background(Theme.down, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(deleting)
                }
            }
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.down.opacity(0.25)))
    }

    // MARK: - Actions

    private func loadMine() async {
        guard let profile = authStore.profile else { return }
        mine = (try? await API.fetchRecipesByAuthor(userId: profile.id)) ?? []
    }

    private func saveUsername() async {
        guard !savingName else { return }
        savingName = true
        nameError = nil
        defer { savingName = false }
        do {
            try await authStore.updateUsername(draftUsername)
            editing = false
        } catch {
            nameError = error.localizedDescription
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard !authStore.isDemo, !avatarBusy, let profile = authStore.profile else { return }
        avatarBusy = true
        defer { avatarBusy = false }
        if let raw = try? await item.loadTransferable(type: Data.self),
           let data = ImageCompressor.jpegData(from: raw, maxDimension: 800, quality: 0.8),
           let url = try? await API.uploadAvatar(userId: profile.id, imageData: data) {
            authStore.setAvatarUrl(url)
        }
    }

    private func deleteAccount() async {
        guard !deleting else { return }
        deleting = true
        deleteError = nil
        do {
            try await authStore.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
            deleting = false
        }
    }
}

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(value).font(.system(size: 22, weight: .heavy)).monospacedDigit()
            }
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
    }
}
