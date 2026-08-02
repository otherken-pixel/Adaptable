import SwiftUI

private enum ChipKind: Equatable {
    case all, forYou, following
    case time(maxMinutes: Int)
    case calories(max: Int)
    case protein(min: Int)
    case tag(String)

    var filterChip: FeedFilter.Chip {
        switch self {
        case .all: return .all
        case .forYou: return .forYou
        case .following: return .following
        case .time(let maxMinutes): return .time(maxMinutes: maxMinutes)
        case .calories(let max): return .calories(max: max)
        case .protein(let min): return .protein(min: min)
        case .tag(let label): return .tag(label)
        }
    }
}

private struct Chip: Identifiable, Equatable {
    let id: String
    let label: String
    let kind: ChipKind
}

private let builtinTagLabels: Set<String> = ["high-protein", "low-cal"]
private let feedTopID = "feed-top"
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
    /// Bumped when filters change so we can scroll the list back to the top.
    @State private var scrollToTopToken = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id(feedTopID)
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
            }
            .onChange(of: deepLinks.feedRefreshToken) { _, _ in
                Task { await load(showSkeleton: false) }
            }
            .onChange(of: deepLinks.feedTagFilter) { _, tag in
                guard let tag else { return }
                selectChip(tagChipId(tag))
                deepLinks.feedTagFilter = nil
            }
            .onChange(of: scrollToTopToken) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(feedTopID, anchor: .top)
                }
            }
        }
    }

    // MARK: - Derived filter (single source of truth)

    /// Always computed from recipes + search + active chip — never a stale
    /// `@State` copy that forgets to update when a chip is tapped.
    private var filteredRecipes: [Recipe] {
        guard let recipes else { return [] }
        return FeedFilter.apply(
            recipes: recipes,
            search: search,
            chip: activeChip.kind.filterChip,
            dietTags: authStore.profile?.preferences?.diets ?? [],
            followedAuthorIds: engagement.followedIds
        )
    }

    private func selectChip(_ id: String) {
        guard activeChipId != id else { return }
        activeChipId = id
        scrollToTopToken &+= 1
    }

    // MARK: - Header

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

    // MARK: - Search + chips

    private var searchAndChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Search recipes, tags, cuisines…", text: $search)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !search.isEmpty {
                    Button {
                        search = ""
                        scrollToTopToken &+= 1
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 22, height: 22)
                            .background(Theme.sunken, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))

            // Horizontal chip strip. Buttons (not nested scroll gestures) drive
            // selection so taps remain reliable inside the parent ScrollView.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        Button {
                            selectChip(chip.id)
                        } label: {
                            Text(chip.label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(activeChipId == chip.id ? Theme.surface : Theme.muted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Capsule())
                                .background(
                                    activeChipId == chip.id ? AnyShapeStyle(Theme.content) : AnyShapeStyle(Theme.raised),
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(activeChipId == chip.id ? .clear : Theme.line))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(activeChipId == chip.id ? .isSelected : [])
                        .accessibilityLabel(chip.label)
                    }
                }
                // Extra vertical padding so hit targets aren't clipped by the strip.
                .padding(.vertical, 2)
            }

            // Confirms a filter took effect even when the top card is unchanged.
            if recipes != nil, activeChipId != "all" || !search.isEmpty {
                Text("\(filteredRecipes.count) \(filteredRecipes.count == 1 ? "recipe" : "recipes")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.faint)
                    .accessibilityLabel("\(filteredRecipes.count) recipes match this filter")
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Empty states

    private var isForYouEmpty: Bool {
        recipes != nil && filteredRecipes.isEmpty && activeChip.kind == .forYou
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
            } else if recipes != nil && filteredRecipes.isEmpty && activeChip.kind == .following {
                EmptyStateView(
                    emoji: "👥",
                    title: "No recipes from chefs you follow",
                    message: "Follow a chef from any recipe page — their new dishes show up here."
                ) {
                    PillButton(title: "Browse Hot recipes") { selectChip("all") }
                }
            } else {
                let filtering = !search.isEmpty || activeChip.kind != .all
                EmptyStateView(
                    emoji: filtering ? "🔍" : "🍳",
                    title: filtering ? "No matches" : "Nothing cooking yet",
                    message: filtering
                        ? "Try a different search or filter — or generate exactly what you're craving."
                        : "Be the first — describe what you're craving and let the AI take it from there."
                ) {
                    PillButton(title: filtering ? "Clear filters & browse" : "Generate a recipe") {
                        if filtering {
                            search = ""
                            selectChip("all")
                        } else {
                            deepLinks.activeTab = .create
                        }
                    }
                }
            }
        }
    }

    // MARK: - Load

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
}
