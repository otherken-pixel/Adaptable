import SwiftUI

private enum CookbookTab { case saved, planner }

/// Saved recipes + meal planner with "send the week to Groceries" in one
/// tap. Mirrors `src/pages/CookbookPage.tsx`.
struct CookbookView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var engagement: EngagementStore
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    @State private var tab: CookbookTab = .saved
    @State private var recipes: [Recipe]?
    @State private var plans: [MealPlanEntry]?
    @State private var weekAdded = false

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
        .onChange(of: engagement.savedIds) { _, _ in Task { await loadSaved() } }
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
        if grouped == nil {
            FeedSkeleton()
        } else if upcomingCount == 0 {
            EmptyStateView(emoji: "🗓️", title: "Nothing planned yet", message: "Open any recipe and tap the calendar button to plan your week — then send the whole week to Groceries in one tap.") {
                PillButton(title: "Find something delicious") { deepLinks.activeTab = .discover }
            }
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
        for (_, entries) in grouped {
            for entry in entries {
                guard let recipe = entry.recipe else { continue }
                shoppingStore.addRecipe(recipe, scaleFactor: Double(entry.servings) / Double(recipe.servings), userId: userId)
            }
        }
        weekAdded = true
        Task {
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
                        Text("\(r.prep_time_minutes + r.cook_time_minutes) min").font(.system(size: 12)).foregroundStyle(Theme.faint)
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
