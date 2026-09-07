import SwiftUI

/// Saved recipes plus this week's canvas. Prep interview lives on Create.
struct CookbookView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var engagement: EngagementStore
    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    @State private var recipes: [Recipe]?
    @State private var plans: [MealPlanEntry]?
    @State private var weekAdded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                weekSection
                savedSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .task { await loadSaved() }
        .task { await loadPlans() }
        .task { await engagement.load(for: authStore.profile) }
        .onChange(of: engagement.savedIds) { _, _ in
            Task { await loadSaved() }
        }
        .onChange(of: deepLinks.activeTab) { _, tab in
            if tab == .cookbook { Task { await loadPlans() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("YOUR KITCHEN").font(.system(size: 12, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.accent)
            Text("Cookbook").font(.system(size: 32, weight: .heavy))
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
                    Button {
                        deepLinks.openCookbookRecipe(r.id)
                    } label: {
                        RecipeCardView(recipe: r, index: i, asLink: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadSaved() async {
        guard let userId = authStore.profile?.id else { return }
        recipes = (try? await API.fetchSavedRecipes(userId: userId)) ?? []
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAVED")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.accent)
                .padding(.top, 28)
            savedContent
        }
    }

    // MARK: - Week

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
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            WeekCanvasView(
                plans: (plans ?? []).filter { $0.plan_date >= Format.localISODate() },
                onMove: { entry, iso in Task { await move(entry, to: iso) } },
                onSelectDay: { _ in }
            )

            if plans == nil {
                FeedSkeleton()
            } else if upcomingCount == 0 {
                EmptyStateView(
                    emoji: "🗓️",
                    title: "Nothing planned yet",
                    message: "Build leftover-friendly meals that share a base — then drop them on the week."
                ) {
                    VStack(spacing: 10) {
                        PillButton(title: "Build this week's prep") { deepLinks.openPrep() }
                        if Nutrition.goals(from: authStore.profile?.preferences).hasAny {
                            PillButton(title: "Generate a plate for today") {
                                let goals = Nutrition.goals(from: authStore.profile?.preferences)
                                let remaining = Nutrition.remaining(goals, totals: Nutrition.Macros())
                                openFillToday(remaining)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
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

                ForEach(grouped ?? [], id: \.0) { iso, entries in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dayLabel(iso)).font(.system(size: 15, weight: .heavy))
                        DayNutritionStrip(
                            entries: entries,
                            goals: Nutrition.goals(from: authStore.profile?.preferences),
                            onFillToday: { remaining in openFillToday(remaining) },
                            onEditGoals: { deepLinks.openTasteProfile() }
                        )
                        VStack(spacing: 10) {
                            ForEach(entries) { entry in
                                PlanRow(
                                    entry: entry,
                                    onOpen: { deepLinks.openCookbookRecipe(entry.recipe_id) },
                                    onServingsChange: { delta in changeServings(entry, delta: delta) },
                                    onEatChange: { delta in changeEatServings(entry, delta: delta) },
                                    onRemove: { remove(entry) }
                                )
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

    private func openFillToday(_ remaining: Nutrition.Macros) {
        let locks = Nutrition.fillLocks(from: remaining)
        deepLinks.openFillToday(
            calories: locks.maxCalories,
            protein: locks.minProtein,
            slot: Nutrition.suggestedFillSlot()
        )
    }

    private func changeEatServings(_ entry: MealPlanEntry, delta: Int) {
        guard let userId = authStore.profile?.id else { return }
        let current = Nutrition.clampEatServings(entry.eat_servings)
        let next = Nutrition.clampEatServings(current + delta)
        guard next != current else { return }
        plans = plans?.map {
            var p = $0
            if p.id == entry.id { p.eat_servings = next }
            return p
        }
        Task {
            do { try await API.updateMealPlanEatServings(userId: userId, id: entry.id, eatServings: next) }
            catch { await loadPlans() }
        }
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

private struct DayNutritionStrip: View {
    let entries: [MealPlanEntry]
    let goals: Nutrition.Goals
    var onFillToday: (Nutrition.Macros) -> Void
    var onEditGoals: () -> Void

    private var day: Nutrition.Day { Nutrition.sumDay(entries) }
    private var remaining: Nutrition.Macros { Nutrition.remaining(goals, totals: day.totals) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                if !goals.hasAny {
                    Button("Set goals", action: onEditGoals)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
            }
            if goals.hasAny, let target = goals.calorie_target, target > 0 {
                ProgressView(value: progress(used: day.totals.calories, target: target))
                    .tint(Theme.accent)
            }
            if day.unknownMeals > 0 {
                Text(day.unknownMeals == 1 ? "1 meal has no estimate" : "\(day.unknownMeals) meals have no estimate")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            if goals.hasAny && Nutrition.shouldOfferFillToday(goals: goals, remaining: remaining) {
                Button {
                    onFillToday(remaining)
                } label: {
                    Text(fillLabel)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(12)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var summary: String {
        var bits: [String] = []
        if let used = day.totals.calories {
            if let target = goals.calorie_target {
                bits.append("\(used) / \(target) cal")
            } else {
                bits.append("\(used) cal planned")
            }
        }
        if let used = day.totals.protein_g {
            if let target = goals.protein_target_g {
                bits.append("\(used) / \(target)g P")
            } else {
                bits.append("\(used)g P")
            }
        }
        return bits.isEmpty ? "No nutrition estimates yet" : bits.joined(separator: " · ")
    }

    private var fillLabel: String {
        if let calories = remaining.calories, calories < 0 {
            return "Generate a lighter plate"
        }
        if let calories = remaining.calories, calories >= Nutrition.fillMinCalories {
            return "Generate something ~\(calories) cal to finish today"
        }
        return "Generate a plate that finishes today"
    }

    private func progress(used: Int?, target: Int) -> Double {
        min(1, Double(used ?? 0) / Double(target))
    }
}

private struct PlanRow: View {
    let entry: MealPlanEntry
    var onOpen: () -> Void
    var onServingsChange: (Int) -> Void
    var onEatChange: (Int) -> Void
    var onRemove: () -> Void

    private var eatServings: Int { Nutrition.clampEatServings(entry.eat_servings) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    ZStack {
                        Gradients.cover(for: entry.recipe_id)
                        Text(entry.recipe?.emoji ?? "🍽️").font(.system(size: 22))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.recipe?.title ?? "Recipe").font(.system(size: 14, weight: .bold)).lineLimit(1).foregroundStyle(Theme.content)
                        Text(metaLine).font(.system(size: 12)).foregroundStyle(Theme.faint)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Theme.faint).frame(width: 32, height: 32)
                }
            }
            HStack(spacing: 8) {
                miniStepper(label: "Cook", value: entry.servings, onChange: onServingsChange)
                miniStepper(label: "Eat", value: eatServings, onChange: onEatChange)
            }
        }
        .padding(10)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
    }

    private var metaLine: String {
        var bits: [String] = []
        if let r = entry.recipe {
            bits.append("\((r.prep_time_minutes ?? 0) + (r.cook_time_minutes ?? 0)) min")
        }
        let macros = Nutrition.formatPlateMeta(entry.recipe, eatServings: eatServings)
        if !macros.isEmpty { bits.append(macros) }
        return bits.joined(separator: " · ")
    }

    private func miniStepper(label: String, value: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint)
            Button { onChange(-1) } label: {
                Image(systemName: "minus").frame(width: 26, height: 26).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
            }
            Text("\(value)").font(.system(size: 12, weight: .heavy)).frame(minWidth: 18)
            Button { onChange(1) } label: {
                Image(systemName: "plus").frame(width: 26, height: 26).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
            }
        }
        .padding(2)
        .background(Theme.sunken, in: Capsule())
    }
}
