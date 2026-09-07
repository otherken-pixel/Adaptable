import SwiftUI

private let diets = ["Vegetarian", "Vegan", "Pescatarian", "Keto", "Paleo", "Gluten-free", "Dairy-free", "Halal", "Kosher", "Low-carb"]
private let allergyOptions = AllergenLexicon.chips
private let spiceOptions = ["Mild", "Medium", "Hot"]
private let skillOptions = ["Beginner", "Confident", "Pro"]

/// Diets, allergies, dislikes, household size, spice, skill — injected into
/// every AI generation. Mirrors `src/pages/TasteProfilePage.tsx`.
struct TasteProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDiets: [String] = []
    @State private var selectedAllergies: [String] = []
    @State private var dislikes: [String] = []
    @State private var dislikeDraft = ""
    @State private var household = 4
    @State private var spice: String?
    @State private var skill: String?
    @State private var calorieTarget: Int?
    @State private var proteinTarget: Int?
    @State private var carbsTarget: Int?
    @State private var fatTarget: Int?
    @State private var mealsPerDay = Nutrition.defaultMealsPerDay
    @State private var showExtraMacros = false
    @State private var saving = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                section("Diets") {
                    ChipGrid(items: diets, selected: selectedDiets) { toggle(&selectedDiets, $0) }
                }
                section("Allergies") {
                    allergyBadge
                } content: {
                    ChipGrid(items: allergyOptions, selected: selectedAllergies, danger: true) { toggle(&selectedAllergies, $0) }
                }
                section("Ingredients you dislike") {
                    dislikesEditor
                }
                section("Daily goals") {
                    Label("Optional", systemImage: "target")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.sunken, in: Capsule())
                } content: {
                    goalsEditor
                }
                section("Household size") {
                    householdStepper
                }
                section("Spice tolerance") {
                    Segmented(options: spiceOptions, value: $spice)
                }
                section("Cooking skill") {
                    Segmented(options: skillOptions, value: $skill)
                }
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .onAppear(perform: loadInitial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            Text("PERSONALIZATION").font(.system(size: 12, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.accent)
            Text("Taste Profile").font(.system(size: 32, weight: .heavy))
            Text("Every recipe the AI creates for you respects this — automatically. Change calorie or macro targets anytime.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)
        }
        .padding(.top, 12)
    }

    private var allergyBadge: some View {
        Label("Always excluded", systemImage: "exclamationmark.shield.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.down)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.down.opacity(0.1), in: Capsule())
    }

    private var dislikesEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !dislikes.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(dislikes, id: \.self) { d in
                        Button { dislikes.removeAll { $0 == d } } label: {
                            HStack(spacing: 6) { Text(d); Image(systemName: "xmark").font(.system(size: 10, weight: .heavy)) }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Theme.accentSoft, in: Capsule())
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("e.g. cilantro, olives, blue cheese…", text: $dislikeDraft)
                    .onSubmit(addDislike)
                Button(action: addDislike) {
                    Image(systemName: "plus").frame(width: 36, height: 36).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                }
                .disabled(dislikeDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
        }
    }

    private func addDislike() {
        let item = dislikeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty else { return }
        if !dislikes.contains(where: { $0.lowercased() == item.lowercased() }) { dislikes.append(item) }
        dislikeDraft = ""
    }

    private var goalsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Used to generate, filter, and plan meals. Estimates only — not medical or dietetic advice. Planner counts one plate per meal, not the household cook yield.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            Text("Calories").font(.system(size: 13, weight: .bold))
            ChipGrid(
                items: Nutrition.caloriePresets.map(String.init) + ["Off"],
                selected: calorieSelection
            ) { item in
                if item == "Off" { calorieTarget = nil }
                else { calorieTarget = Int(item) }
            }
            stepperRow(title: "Custom kcal", value: calorieTarget ?? 0, range: Nutrition.minCalorieTarget...Nutrition.maxCalorieTarget, allowZero: true) { next in
                calorieTarget = next == 0 ? nil : next
            }
            Text("Protein").font(.system(size: 13, weight: .bold))
            ChipGrid(
                items: Nutrition.proteinPresets.map { "\($0)g" } + ["Off"],
                selected: proteinSelection
            ) { item in
                if item == "Off" { proteinTarget = nil }
                else { proteinTarget = Int(item.replacingOccurrences(of: "g", with: "")) }
            }
            stepperRow(title: "Custom grams", value: proteinTarget ?? 0, range: Nutrition.minMacroG...Nutrition.maxMacroG, allowZero: true, step: 5) { next in
                proteinTarget = next == 0 ? nil : next
            }
            HStack {
                Text("Meals I track").font(.system(size: 14, weight: .bold))
                Spacer()
                HStack(spacing: 4) {
                    Button { mealsPerDay = max(Nutrition.minMealsPerDay, mealsPerDay - 1) } label: {
                        Image(systemName: "minus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                    }
                    Text("\(mealsPerDay) / day").font(.system(size: 13, weight: .heavy)).frame(minWidth: 64)
                    Button { mealsPerDay = min(Nutrition.maxMealsPerDay, mealsPerDay + 1) } label: {
                        Image(systemName: "plus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                    }
                }
                .padding(4)
                .background(Theme.sunken, in: Capsule())
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))

            Button {
                showExtraMacros.toggle()
            } label: {
                Text(showExtraMacros ? "Hide carbs & fat" : "Add carbs & fat targets")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            if showExtraMacros {
                stepperRow(title: "Carbs (g)", value: carbsTarget ?? 0, range: Nutrition.minMacroG...Nutrition.maxMacroG, allowZero: true, step: 5) { next in
                    carbsTarget = next == 0 ? nil : next
                }
                stepperRow(title: "Fat (g)", value: fatTarget ?? 0, range: Nutrition.minMacroG...Nutrition.maxMacroG, allowZero: true, step: 5) { next in
                    fatTarget = next == 0 ? nil : next
                }
            }
        }
    }

    private var calorieSelection: [String] {
        if let calorieTarget, Nutrition.caloriePresets.contains(calorieTarget) { return ["\(calorieTarget)"] }
        if calorieTarget == nil { return ["Off"] }
        return []
    }

    private var proteinSelection: [String] {
        if let proteinTarget, Nutrition.proteinPresets.contains(proteinTarget) { return ["\(proteinTarget)g"] }
        if proteinTarget == nil { return ["Off"] }
        return []
    }

    private func stepperRow(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        allowZero: Bool,
        step: Int = 50,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .bold))
            Spacer()
            HStack(spacing: 4) {
                Button {
                    if value <= range.lowerBound { onChange(allowZero ? 0 : range.lowerBound) }
                    else { onChange(max(range.lowerBound, value - step)) }
                } label: {
                    Image(systemName: "minus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
                Text(value == 0 ? "Off" : "\(value)").font(.system(size: 13, weight: .heavy)).frame(minWidth: 56)
                Button { onChange(min(range.upperBound, (value == 0 ? range.lowerBound : value) + step)) } label: {
                    Image(systemName: "plus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
            }
            .padding(4)
            .background(Theme.sunken, in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
    }

    private var householdStepper: some View {
        HStack {
            Text("Usually cooking for").font(.system(size: 14, weight: .bold))
            Spacer()
            HStack(spacing: 4) {
                Button { household = max(1, household - 1) } label: {
                    Image(systemName: "minus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
                Text("\(household) \(household == 1 ? "person" : "people")").font(.system(size: 13, weight: .heavy)).frame(minWidth: 64)
                Button { household = min(12, household + 1) } label: {
                    Image(systemName: "plus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
            }
            .padding(4)
            .background(Theme.sunken, in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 8) {
                if saved {
                    Image(systemName: "checkmark"); Text("Saved")
                } else if saving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save taste profile")
                }
            }
            .font(.system(size: 16, weight: .heavy))
            .frame(maxWidth: .infinity).frame(height: 56)
            .foregroundStyle(.white)
            .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(saving ? 0.6 : 1)
        }
        .disabled(saving)
    }

    private func toggle(_ list: inout [String], _ item: String) {
        if list.contains(item) { list.removeAll { $0 == item } } else { list.append(item) }
    }

    private func loadInitial() {
        guard let prefs = authStore.profile?.preferences else { return }
        selectedDiets = prefs.diets ?? []
        selectedAllergies = prefs.allergies ?? []
        dislikes = prefs.dislikes ?? []
        household = prefs.household_size ?? 4
        spice = prefs.spice
        skill = prefs.skill
        let goals = Nutrition.goals(from: prefs)
        calorieTarget = goals.calorie_target
        proteinTarget = goals.protein_target_g
        carbsTarget = goals.carbs_target_g
        fatTarget = goals.fat_target_g
        mealsPerDay = goals.meals_per_day
        showExtraMacros = goals.carbs_target_g != nil || goals.fat_target_g != nil
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        var prefs = authStore.profile?.preferences ?? .empty
        prefs.diets = selectedDiets
        prefs.allergies = selectedAllergies
        prefs.dislikes = dislikes
        prefs.household_size = household
        prefs.spice = spice
        prefs.skill = skill
        prefs.calorie_target = Nutrition.clampCalorieTarget(calorieTarget)
        prefs.protein_target_g = Nutrition.clampMacroGrams(proteinTarget)
        prefs.carbs_target_g = Nutrition.clampMacroGrams(carbsTarget)
        prefs.fat_target_g = Nutrition.clampMacroGrams(fatTarget)
        prefs.meals_per_day = Nutrition.clampMealsPerDay(mealsPerDay)
        do {
            try await authStore.updatePreferences(prefs)
            saved = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            // best-effort; leave the form as-is
        }
    }

    private func section<Content: View, Badge: View>(
        _ title: String,
        @ViewBuilder badge: () -> Badge = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 15, weight: .heavy))
                badge()
            }
            content()
        }
    }
}

private struct ChipGrid: View {
    let items: [String]
    let selected: [String]
    var danger: Bool = false
    var onToggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let active = selected.contains(item)
                Button { onToggle(item) } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(active ? (danger ? .white : Theme.surface) : Theme.muted)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(active ? AnyShapeStyle(danger ? Theme.down : Theme.content) : AnyShapeStyle(Theme.raised), in: Capsule())
                        .overlay(Capsule().stroke(active ? .clear : Theme.line))
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

private struct Segmented: View {
    let options: [String]
    @Binding var value: String?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { opt in
                Button {
                    value = (value == opt) ? nil : opt
                } label: {
                    Text(opt)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(value == opt ? Theme.content : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(value == opt ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(4)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 18))
    }
}
