import SwiftUI

private enum CookbookTab { case saved, planner }

/// Saved recipes + meal planner + prep-bundle suggestions.
/// Planner "Prep this week" is native-first (web Cookbook stays as-is).
struct CookbookView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var engagement: EngagementStore
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    @State private var tab: CookbookTab = .saved
    @State private var recipes: [Recipe]?
    @State private var plans: [MealPlanEntry]?
    @State private var weekAdded = false
    @State private var bundles: [MealPrepBundle]?
    @State private var completingId: String?
    @State private var buildingFromScratch = false
    @State private var addedBundleId: String?
    @State private var bundleError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                switch tab {
                case .saved: savedContent
                case .planner: plannerContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .task { await loadSaved() }
        .task { await loadPlans() }
        .task { await loadBundles() }
        .task { await engagement.load(for: authStore.profile) }
        .onChange(of: engagement.savedIds) { _, _ in
            Task { await loadSaved(); await loadBundles() }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR KITCHEN").font(.system(size: 12, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.accent)
                Text("Cookbook").font(.system(size: 32, weight: .heavy))
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach([(CookbookTab.saved, "Saved"), (.planner, "Planner")], id: \.1) { t, label in
                    Button { tab = t } label: {
                        Text(label).font(.system(size: 13, weight: .bold))
                            .foregroundStyle(tab == t ? Theme.content : Theme.muted)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(tab == t ? Theme.raised : .clear, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(4)
            .background(Theme.sunken, in: Capsule())
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Saved

    private var visible: [Recipe] {
        (recipes ?? []).filter { engagement.savedIds.contains($0.id) }
    }

    @ViewBuilder
    private var savedContent: some View {
        if recipes == nil {
            FeedSkeleton()
        } else if visible.isEmpty {
            EmptyStateView(emoji: "📖", title: "Your cookbook is empty", message: "Tap the bookmark on any recipe to keep it here forever.") {
                PillButton(title: "Browse recipes") { deepLinks.activeTab = .discover }
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { i, r in
                    RecipeCardView(recipe: r, index: i)
                }
            }
        }
    }

    private func loadSaved() async {
        guard let userId = authStore.profile?.id else { return }
        recipes = (try? await API.fetchSavedRecipes(userId: userId)) ?? []
    }

    // MARK: - Planner

    private var grouped: [(String, [MealPlanEntry])]? {
        guard let plans else { return nil }
        let today = Format.localISODate()
        let upcoming = plans.filter { $0.plan_date >= today && $0.recipe != nil }
        var byDay: [String: [MealPlanEntry]] = [:]
        for p in upcoming { byDay[p.plan_date, default: []].append(p) }
        return byDay.sorted { $0.key < $1.key }
    }

    private var upcomingCount: Int { grouped?.reduce(0) { $0 + $1.1.count } ?? 0 }

    @ViewBuilder
    private var plannerContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            prepBundlesSection

            if let plans {
                WeekCanvasView(
                    plans: plans.filter { $0.plan_date >= Format.localISODate() },
                    onMove: { entry, iso in Task { await move(entry, to: iso) } },
                    onSelectDay: { _ in }
                )
            }

            if grouped == nil {
                FeedSkeleton()
            } else if upcomingCount == 0 {
                EmptyStateView(emoji: "🗓️", title: "Nothing planned yet", message: "Add a prep bundle above, or open any recipe and tap the calendar button.") {
                    PillButton(title: "Find something delicious") { deepLinks.activeTab = .discover }
                }
                .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Button {
                        addWeekToGroceries()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: weekAdded ? "checkmark" : "basket.fill")
                            Text(weekAdded ? "Everything's on the grocery list" : "Add \(upcomingCount) planned \(upcomingCount == 1 ? "meal" : "meals") to Groceries")
                                .font(.system(size: 15, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .foregroundStyle(weekAdded ? Theme.accent : Theme.surface)
                        .background(weekAdded ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(Theme.content), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.pressable)

                    ForEach(grouped!, id: \.0) { iso, entries in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dayLabel(iso)).font(.system(size: 15, weight: .heavy))
                            VStack(spacing: 10) {
                                ForEach(entries) { entry in
                                    PlanRow(entry: entry, onServingsChange: { delta in changeServings(entry, delta: delta) }, onRemove: { remove(entry) })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var prepBundlesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PREP THIS WEEK")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Theme.accent)
                    Text("2–3 meals that share a base or cook at the same time.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Button {
                    Task { await buildFromScratch() }
                } label: {
                    HStack(spacing: 4) {
                        if buildingFromScratch {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(buildingFromScratch ? "Building…" : "Build me one")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accentSoft, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(buildingFromScratch || completingId != nil)
            }

            if let bundleError {
                Text(bundleError)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.down)
            }

            if bundles == nil {
                VStack(spacing: 12) {
                    RecipeCardSkeleton()
                    RecipeCardSkeleton()
                }
            } else if let bundles, bundles.isEmpty {
                Text("Save a couple of recipes — or tap Build me one and we’ll generate a leftover-friendly trio around your taste profile.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            } else if let bundles {
                VStack(spacing: 14) {
                    ForEach(bundles) { bundle in
                        MealPrepBundleCard(
                            bundle: bundle,
                            isCompleting: completingId == bundle.id,
                            justAdded: addedBundleId == bundle.id,
                            onAddToWeek: { Task { await addBundleToWeek(bundle) } },
                            onComplete: { Task { await complete(bundle) } }
                        )
                    }
                }
            }
        }
    }

    private func loadBundles() async {
        guard let userId = authStore.profile?.id else { return }
        let pool = (try? await API.fetchBundlePool(userId: userId)) ?? []
        let prefs = authStore.profile?.preferences ?? .empty
        bundles = MealPrepBundles.select(pool: pool, prefs: prefs)
    }

    private func complete(_ bundle: MealPrepBundle) async {
        completingId = bundle.id
        bundleError = nil
        do {
            let done = try await API.completeBundle(seedIds: bundle.recipes.map(\.id), kind: bundle.kind)
            if let idx = bundles?.firstIndex(where: { $0.id == bundle.id }) {
                bundles?[idx] = done
            } else {
                bundles?.insert(done, at: 0)
            }
            deepLinks.requestFeedRefresh()
            Haptics.success()
        } catch {
            bundleError = AppError.friendlyMessage(for: error)
            Haptics.warning()
        }
        completingId = nil
    }

    private func buildFromScratch() async {
        buildingFromScratch = true
        bundleError = nil
        do {
            let done = try await API.completeBundle(seedIds: [], kind: .sharedBase)
            bundles = [done] + (bundles ?? []).filter { $0.id != done.id }
            deepLinks.requestFeedRefresh()
            Haptics.success()
        } catch {
            bundleError = AppError.friendlyMessage(for: error)
            Haptics.warning()
        }
        buildingFromScratch = false
    }

    private func addBundleToWeek(_ bundle: MealPrepBundle) async {
        guard let userId = authStore.profile?.id else { return }
        let household = authStore.profile?.preferences?.household_size
        let sameDay = bundle.kind == .concurrent
        let parentId = bundle.recipes.first?.id
        let focus = bundle.leftover_focus.first
        for (i, recipe) in bundle.recipes.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: sameDay ? 0 : i, to: Date()) ?? Date()
            let servings = household ?? recipe.servings ?? 2
            let isLeftover = bundle.kind == .sharedBase && i > 0 && parentId != recipe.id
            do {
                try await API.addMealPlan(
                    userId: userId,
                    recipeId: recipe.id,
                    planDate: Format.localISODate(date),
                    servings: servings,
                    leftoverOf: isLeftover ? parentId : nil,
                    leftoverFocus: isLeftover ? focus : nil
                )
            } catch {
                bundleError = AppError.friendlyMessage(for: error)
                return
            }
        }
        await shoppingStore.addBundle(bundle, userId: userId, householdSize: household)
        weekAdded = true
        if let prefs = authStore.profile?.preferences {
            try? await authStore.updatePreferences(TasteMemory.recordLeftover(focus: bundle.leftover_focus, prefs: prefs))
        }
        addedBundleId = bundle.id
        Haptics.success()
        await loadPlans()
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if addedBundleId == bundle.id { addedBundleId = nil }
        }
    }

    private func dayLabel(_ iso: String) -> String {
        let today = Format.localISODate()
        let tomorrow = Format.localISODate(Date(timeIntervalSinceNow: 86_400))
        if iso == today { return "Today" }
        if iso == tomorrow { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        if let date = ISO8601DateFormatter().date(from: iso + "T12:00:00Z") { return f.string(from: date) }
        return iso
    }

    private func loadPlans() async {
        guard let userId = authStore.profile?.id else { return }
        plans = (try? await API.fetchMealPlans(userId: userId)) ?? []
        KitchenSnapshot.refresh(from: plans ?? [])
    }

    private func move(_ entry: MealPlanEntry, to iso: String) async {
        guard let userId = authStore.profile?.id else { return }
        plans = plans?.map {
            var p = $0
            if p.id == entry.id { p.plan_date = iso }
            return p
        }
        try? await API.updateMealPlanDate(userId: userId, id: entry.id, planDate: iso)
        KitchenSnapshot.refresh(from: plans ?? [])
    }

    private func changeServings(_ entry: MealPlanEntry, delta: Int) {
        guard let userId = authStore.profile?.id else { return }
        let next = min(24, max(1, entry.servings + delta))
        guard next != entry.servings else { return }
        plans = plans?.map {
            var p = $0
            if p.id == entry.id { p.servings = next }
            return p
        }
        Task {
            do { try await API.updateMealPlanServings(userId: userId, id: entry.id, servings: next) }
            catch { await loadPlans() }
        }
    }

    private func remove(_ entry: MealPlanEntry) {
        guard let userId = authStore.profile?.id else { return }
        plans = plans?.filter { $0.id != entry.id }
        Task {
            do { try await API.removeMealPlan(userId: userId, id: entry.id) }
            catch { await loadPlans() }
        }
    }

    private func addWeekToGroceries() {
        guard let grouped, !weekAdded, let userId = authStore.profile?.id else { return }
        weekAdded = true
        Task {
            for (_, entries) in grouped {
                for entry in entries {
                    guard let recipe = entry.recipe else { continue }
                    var skip = Set<String>()
                    if let focus = entry.leftover_focus, !focus.isEmpty {
                        skip.insert(MealPrepBundles.normalizeIngredient(focus))
                    }
                    await shoppingStore.addRecipe(
                        recipe,
                        scaleFactor: Double(entry.servings) / Double(max(recipe.servings ?? 1, 1)),
                        userId: userId,
                        skipKeys: skip
                    )
                }
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            weekAdded = false
        }
    }
}

private struct PlanRow: View {
    let entry: MealPlanEntry
    var onServingsChange: (Int) -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: Route.recipe(id: entry.recipe_id)) {
                ZStack {
                    Gradients.cover(for: entry.recipe_id)
                    Text(entry.recipe?.emoji ?? "🍽️").font(.system(size: 22))
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            NavigationLink(value: Route.recipe(id: entry.recipe_id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.recipe?.title ?? "Recipe").font(.system(size: 14, weight: .bold)).lineLimit(1).foregroundStyle(Theme.content)
                    if let r = entry.recipe {
                        Text("\((r.prep_time_minutes ?? 0) + (r.cook_time_minutes ?? 0)) min").font(.system(size: 12)).foregroundStyle(Theme.faint)
                    }
                }
            }
            Spacer()
            HStack(spacing: 2) {
                Button { onServingsChange(-1) } label: {
                    Image(systemName: "minus").frame(width: 26, height: 26).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
                Text("\(entry.servings)").font(.system(size: 12, weight: .heavy)).frame(minWidth: 22)
                Button { onServingsChange(1) } label: {
                    Image(systemName: "plus").frame(width: 26, height: 26).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
            }
            .padding(2)
            .background(Theme.sunken, in: Capsule())
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Theme.faint).frame(width: 32, height: 32)
            }
        }
        .padding(10)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
    }
}
