import SwiftUI

/// Full recipe render: hero, stats, scalable ingredient checklist, steps.
/// Shared by the Recipe Detail screen and the Generate result screen.
/// Mirrors `src/components/RecipeView.tsx`.
struct RecipeContentView: View {
    let recipe: Recipe

    @EnvironmentObject private var shoppingStore: ShoppingStore
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter

    @State private var checked: Set<Int> = []
    @State private var servings: Int
    @State private var addedToList = false
    @State private var planOpen = false
    @State private var planned: String?
    @State private var shareItem: ShareItem?

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: recipe.servings ?? 1)
    }

    private var factor: Double { Double(servings) / Double(max(1, recipe.servings ?? 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            hero
            titleBlock
            statBand
            if recipe.protein_g != nil || recipe.carbs_g != nil || recipe.fat_g != nil {
                macroBand
            }
            actionButtons
            if let planned {
                Text("Planned for \(planned) (\(servings) servings) — see it in Cookbook → Planner")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
            }
            ingredientsSection
            stepsSection
            voteShareBar
            remixButton
        }
        .sheet(isPresented: $planOpen) { dayPickerSheet }
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.text]) }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Gradients.cover(for: recipe.id).frame(height: 224)
            Text(recipe.emoji ?? "").font(.system(size: 96)).frame(maxWidth: .infinity).floating
            Text(recipe.cuisine ?? "")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(16)
        }
        .frame(height: 224)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.title ?? "").font(.system(size: 26, weight: .heavy))
            Text(recipe.description ?? "").font(.system(size: 15)).foregroundStyle(Theme.muted)
            if !(recipe.tags ?? []).isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(recipe.tags ?? [], id: \.self) { tag in
                        Button {
                            deepLinks.openFeed(tag: tag)
                        } label: {
                            Text(tag)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Theme.accentSoft, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            if (recipe.cook_count ?? 0) > 0 {
                Text("🍳 Cooked \(recipe.cook_count ?? 0) \((recipe.cook_count ?? 0) == 1 ? "time" : "times") by the community")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            if let sourceURL = recipe.source_url, let url = URL(string: sourceURL) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text("Imported from \(url.host?.replacingOccurrences(of: "www.", with: "") ?? "source")")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.sunken, in: Capsule())
                }
            }
        }
    }

    // MARK: - Stat band

    private var statBand: some View {
        HStack {
            StatColumn(icon: "clock", value: "\((recipe.prep_time_minutes ?? 0) + (recipe.cook_time_minutes ?? 0))m", label: "Total")
            Spacer()
            StatColumn(icon: "flame", value: "\(recipe.cook_time_minutes ?? 0)m", label: "Cook")
            Spacer()
            StatColumn(icon: "person.2", value: "\(servings)", label: "Serves")
            Spacer()
            StatColumn(icon: "gauge.medium", value: recipe.difficulty?.rawValue ?? "", label: "Level")
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
    }

    private var macroBand: some View {
        HStack {
            MacroColumn(value: recipe.calories, unit: "", label: "Calories")
            Spacer()
            MacroColumn(value: recipe.protein_g, unit: "g", label: "Protein")
            Spacer()
            MacroColumn(value: recipe.carbs_g, unit: "g", label: "Carbs")
            Spacer()
            MacroColumn(value: recipe.fat_g, unit: "g", label: "Fat")
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
    }

    // MARK: - Start cooking + plan

    private var actionButtons: some View {
        HStack(spacing: 12) {
            NavigationLink(value: Route.cookMode(id: recipe.id, servings: servings)) {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                    Text("Start Cooking").font(.system(size: 16, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.25), radius: 16, y: 6)
            }
            .buttonStyle(.pressable)

            Button {
                planOpen = true
            } label: {
                Image(systemName: planned != nil ? "checkmark" : "calendar.badge.plus")
                    .font(.system(size: 19))
                    .frame(width: 56, height: 56)
                    .foregroundStyle(planned != nil ? Theme.accent : Theme.muted)
                    .background(planned != nil ? Theme.accentSoft : Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(planned != nil ? .clear : Theme.line))
            }
            .buttonStyle(.pressable)
        }
    }

    private var dayPickerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(Theme.line).frame(width: 40, height: 5).frame(maxWidth: .infinity)
            Text("Plan \u{201C}\(recipe.title ?? "")\u{201D}").font(.system(size: 18, weight: .heavy))
            Text("\(servings) \(servings == 1 ? "serving" : "servings") — pick a day.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(nextDays(8), id: \.iso) { day in
                    Button {
                        planFor(day.iso, label: day.label)
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.label).font(.system(size: 13, weight: .heavy))
                            Text(day.sub).font(.system(size: 11)).foregroundStyle(Theme.faint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
                    }
                    .buttonStyle(.pressable)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.height(340)])
    }

    private func planFor(_ iso: String, label: String) {
        guard let userId = authStore.profile?.id else { return }
        Task { try? await API.addMealPlan(userId: userId, recipeId: recipe.id, planDate: iso, servings: servings) }
        planOpen = false
        planned = label
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            planned = nil
        }
    }

    private func nextDays(_ count: Int) -> [(iso: String, label: String, sub: String)] {
        (0..<count).map { i in
            let date = Calendar.current.date(byAdding: .day, value: i, to: Date())!
            let iso = Format.localISODate(date)
            let label: String
            if i == 0 { label = "Today" } else if i == 1 { label = "Tomorrow" } else {
                let f = DateFormatter(); f.dateFormat = "EEE"
                label = f.string(from: date)
            }
            let sub = i == 0 ? "" : String(iso.suffix(5))
            return (iso, label, sub)
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients").font(.system(size: 18, weight: .heavy))
                Spacer()
                Stepper(value: $servings, in: 1...24) {
                    Text("\(servings) \(servings == 1 ? "serving" : "servings")")
                        .font(.system(size: 13, weight: .heavy))
                }
            }

            VStack(spacing: 0) {
                ForEach(Array((recipe.ingredients ?? []).enumerated()), id: \.offset) { i, ing in
                    if i > 0 { Divider().overlay(Theme.line) }
                    Button {
                        toggle(i)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(checked.contains(i) ? Theme.accent : Theme.line, lineWidth: 2)
                                .background(Circle().fill(checked.contains(i) ? Theme.accent : .clear))
                                .frame(width: 22, height: 22)
                                .overlay(checked.contains(i) ? Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.white) : nil)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.item)
                                    .font(.system(size: 15, weight: .semibold))
                                    .strikethrough(checked.contains(i))
                                if let note = ing.note {
                                    Text(note).font(.system(size: 11)).foregroundStyle(Theme.faint)
                                }
                            }
                            Spacer()
                            Text(Quantity.scale(ing.quantity, factor: factor))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.muted)
                                .monospacedDigit()
                        }
                        .opacity(checked.contains(i) ? 0.45 : 1)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))

            Button {
                addToGroceries()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: addedToList ? "checkmark" : "basket")
                    Text(addedToList ? "\((recipe.ingredients ?? []).count) items added to Groceries" : "Add all to Groceries")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(addedToList ? Theme.accent : Theme.content)
                .background(addedToList ? Theme.accentSoft : Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(addedToList ? .clear : Theme.line))
            }
            .buttonStyle(.pressable)
        }
    }

    private func toggle(_ i: Int) {
        if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
    }

    private func addToGroceries() {
        guard !addedToList, let userId = authStore.profile?.id else { return }
        shoppingStore.addRecipe(recipe, scaleFactor: factor, userId: userId)
        addedToList = true
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            addedToList = false
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method").font(.system(size: 18, weight: .heavy))
            VStack(spacing: 12) {
                ForEach(recipe.steps ?? []) { step in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.step)")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.surface)
                                .frame(width: 28, height: 28)
                                .background(Theme.content, in: Circle())
                            Text(step.instruction).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                        }
                        if let tip = step.tip {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill").font(.system(size: 13)).foregroundStyle(Theme.accent)
                                Text(tip).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.accent)
                            }
                            .padding(.leading, 40)
                        }
                    }
                    .padding(14)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
                }
            }
        }
    }

    // MARK: - Action bar

    private var voteShareBar: some View {
        HStack(spacing: 12) {
            VotePillView(recipeId: recipe.id, baseCount: recipe.net_upvotes ?? 0, size: .lg)
            SaveButtonView(recipeId: recipe.id, variant: .bar)
            Button {
                shareItem = ShareItem(text: "\(recipe.emoji ?? "") \(recipe.title ?? "") — made with Adaptable")
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 48, height: 48)
                    .foregroundStyle(Theme.muted)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
            }
            .buttonStyle(.pressable)
        }
    }

    private var remixButton: some View {
        Button {
            deepLinks.openRemix(recipe.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "shuffle").foregroundStyle(Theme.accent)
                Text("Remix this recipe — make it yours").font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(Theme.muted)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5])))
        }
        .buttonStyle(.pressable)
    }
}

private struct StatColumn: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.accent)
            Text(value).font(.system(size: 15, weight: .heavy)).monospacedDigit()
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint)
        }
    }
}

private struct MacroColumn: View {
    let value: Int?; let unit: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value.map { "\($0)\(unit)" } ?? "—").font(.system(size: 15, weight: .heavy)).monospacedDigit()
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint)
        }
    }
}

struct ShareItem: Identifiable { let id = UUID(); let text: String }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Minimal wrapping flow layout for tag pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
