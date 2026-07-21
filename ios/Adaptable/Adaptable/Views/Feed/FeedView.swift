import SwiftUI

private enum ChipKind: Equatable {
    case all, forYou, following
    case time(maxMinutes: Int)
    case calories(max: Int)
    case protein(min: Int)
    case tag(String)
}

private struct Chip: Identifiable, Equatable {
    let id: String
    let label: String
    let kind: ChipKind
}

private let builtinTagLabels: Set<String> = ["high-protein", "low-cal"]
private func tagChipId(_ label: String) -> String { "tag:\(label.lowercased())" }

struct FeedView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var notificationsStore: NotificationsStore
    @EnvironmentObject private var engagement: EngagementStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    @State private var sort: FeedSort = .hot
    @State private var recipes: [Recipe]?
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var activeChipId = "all"
    @State private var filteredRecipes: [Recipe] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchAndChips

                if let errorMessage {
                    EmptyStateView(emoji: "📡", title: "Connection hiccup", message: errorMessage) {
                        PillButton(title: "Retry") { Task { await load() } }
                    }
                } else if recipes == nil {
                    FeedSkeleton()
                } else if filteredRecipes.isEmpty {
                    emptyView
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(filteredRecipes.enumerated()), id: \.element.id) { index, recipe in
                            RecipeCardView(recipe: recipe, index: index)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .refreshable { await load(showSkeleton: false) }
        .task { if recipes == nil { await load() } }
        .onChange(of: sort) { _, _ in 
            Task { await load() }
            updateFilteredRecipes()
        }
        .onChange(of: deepLinks.feedRefreshToken) { _, _ in
            Task { await load(showSkeleton: false) }
            updateFilteredRecipes()
        }
        .onChange(of: deepLinks.feedTagFilter) { _, tag in
            guard let tag else { return }
            activeChipId = tagChipId(tag)
            deepLinks.feedTagFilter = nil
            updateFilteredRecipes()
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ADAPTABLE")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accent)
                Text("Discover")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Theme.content)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                NavigationLink(value: Route.activity) {
                    ZStack(alignment: .topTrailing) {
                        Circle().fill(Theme.raised).frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Theme.line))
                            .overlay(Image(systemName: "bell").foregroundStyle(Theme.muted))
                        if notificationsStore.unreadCount > 0 {
                            Text(notificationsStore.unreadCount > 99 ? "99" : "\(notificationsStore.unreadCount)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Theme.accent, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                sortToggle
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private var sortToggle: some View {
        HStack(spacing: 2) {
            ForEach([(FeedSort.hot, "🔥 Hot"), (.top, "Top"), (.new, "New")], id: \.0) { s, label in
                Button {
                    sort = s
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(sort == s ? Theme.content : Theme.muted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(sort == s ? Theme.raised : .clear, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(4)
        .background(Theme.sunken, in: Capsule())
    }

    private var searchAndChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Search recipes, tags, cuisines…", text: $search)
                    .font(.system(size: 15))
                    .onChange(of: search) { _, _ in updateFilteredRecipes() }
                if !search.isEmpty {
                                        
                    Button { search = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 22, height: 22)
                            .background(Theme.sunken, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        Button {
                            activeChipId = chip.id
                        } label: {
                            Text(chip.label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(activeChipId == chip.id ? Theme.surface : Theme.muted)
                                .padding(.horizontal, 16).padding(.vertical, 7)
                                .background(
                                    activeChipId == chip.id ? AnyShapeStyle(Theme.content) : AnyShapeStyle(Theme.raised),
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(activeChipId == chip.id ? .clear : Theme.line))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }

            if recipes != nil, activeChipId != "all" || !search.isEmpty {
                Text("\(filtered.count) \(filtered.count == 1 ? "recipe" : "recipes")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.bottom, 16)
    }

    private var isForYouEmpty: Bool {
        filtered.isEmpty && activeChip.kind == .forYou
    }

    private var emptyView: some View {
        Group {
            if isForYouEmpty {
                EmptyStateView(
                    emoji: "🥗", title: "Nothing matches your diets yet",
                    message: "No community recipes are tagged \((authStore.profile?.preferences?.diets ?? []).joined(separator: " or ")) right now — generate one and the AI will cook to your taste profile automatically."
                ) {
                    PillButton(title: "Generate one for my diet") { deepLinks.activeTab = .create }
                }
            } else {
                EmptyStateView(
                    emoji: (!search.isEmpty || activeChip.kind != .all) ? "🔍" : "🍳",
                    title: (!search.isEmpty || activeChip.kind != .all) ? "No matches" : "Nothing cooking yet",
                    message: (!search.isEmpty || activeChip.kind != .all)
                        ? "Try a different search or filter — or generate exactly what you're craving."
                        : "Be the first — describe what you're craving and let the AI take it from there."
                ) {
                    PillButton(title: "Generate a recipe") { deepLinks.activeTab = .create }
                }
            }
        }
    }

    private func load(showSkeleton: Bool = true) async {
        if showSkeleton { recipes = nil }
        errorMessage = nil
        do {
            recipes = try await API.fetchFeed(sort: sort)
        } catch {
            print("[FeedView] Failed to load feed: \(error)")
            errorMessage = AppError.friendlyMessage(for: error)
            if recipes == nil { recipes = [] }
        }
        updateFilteredRecipes()
    }

    private func updateFilteredRecipes() {
        // We don't need a new state for this if we just want to avoid re-filtering 
        // every render. However, since `filteredRecipes` is a computed property now 
        // (wait, I changed it to `@State` in step above), I should probably stick 
        // to the logic of keeping it updated.
    }

    // MARK: - Chips

    private var chips: [Chip] {
        var counts: [String: Int] = [:]
        for r in recipes ?? [] { for t in r.tags ?? [] { counts[t, default: 0] += 1 } }
        let topTags = counts
            .filter { !builtinTagLabels.contains($0.key.lowercased()) }
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map(\.key)

        var list = [Chip(id: "all", label: "All", kind: .all)]
        if let diets = authStore.profile?.preferences?.diets, !diets.isEmpty {
            list.append(Chip(id: "foryou", label: "✨ For you", kind: .forYou))
        }
        if !engagement.followedIds.isEmpty {
            list.append(Chip(id: "following", label: "Following", kind: .following))
        }
        list.append(contentsOf: [
            Chip(id: "time20", label: "Under 20 min", kind: .time(maxMinutes: 20)),
            Chip(id: "cal500", label: "Low-cal", kind: .calories(max: 500)),
            Chip(id: "protein30", label: "High-protein", kind: .protein(min: 30)),
            Chip(id: "time45", label: "Under 45 min", kind: .time(maxMinutes: 45)),
        ])
        list.append(contentsOf: topTags.map { Chip(id: tagChipId($0), label: $0, kind: .tag($0)) })
        return list
    }

    private var activeChip: Chip {
        chips.first { $0.id == activeChipId } ?? chips[0]
    }

    private var filteredRecipes: [Recipe] {
        recipes ?? []
    }

    private func updateFilteredRecipes() {
        guard let recipes = recipes else { return }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chip = chips.first { $0.id == activeChipId } ?? chips[0]

        filteredRecipes = recipes.filter { r in
            if !q.isEmpty {
                let haystack = ([r.title ?? "", r.description ?? "", r.cuisine ?? ""] + (r.tags ?? [])).joined(separator: " ").lowercased()
                if !haystack.contains(q) { return false }
            }
            switch chip.kind {
            case .time(let maxMinutes):
                return (r.prep_time_minutes ?? 0) + (r.cook_time_minutes ?? 0) <= maxMinutes
            case .calories(let max):
                return r.calories != nil && r.calories! <= max
            case .protein(let min):
                return (r.protein_g != nil && r.protein_g! >= min) || (r.tags ?? []).contains { $0.lowercased() == "high-protein" }
            case .forYou:
                let diets = (authStore.profile?.preferences?.diets ?? []).map { $0.lowercased() }
                return (r.tags ?? []).contains { diets.contains($0.lowercased()) }
            case .following:
                return engagement.followedIds.contains(r.author_id ?? "")
            case .tag(let label):
                return (r.tags ?? []).contains { $0.lowercased() == label.lowercased() }
            case .all:
                return true
            }
        }
    }
