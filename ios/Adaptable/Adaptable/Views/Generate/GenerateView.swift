import SwiftUI
import PhotosUI

private enum CreateMode: Equatable { case describe, pantry, importMode, prep }
private enum Phase: Equatable { case idle, loading, done, error }
private enum PrepWindow: String, CaseIterable {
    case quick = "30"
    case hour = "60"
    case sunday = "120"
    var label: String {
        switch self {
        case .quick: return "30 min"
        case .hour: return "~1 hour"
        case .sunday: return "Sunday 2 hours"
        }
    }
}

private let suggestions = [
    "High-protein vegan dinner in 20 minutes 💪",
    "Date night pasta, restaurant-level 🕯️",
    "Something cozy with what's in my pantry 🫘",
    "Kid-friendly hidden-veggie dinner 🥦",
    "Spicy 15-minute noodles 🌶️",
    "Impressive dessert, minimal effort 🍫",
]

private let remixSuggestions = [
    "Make it vegan 🌱", "Gluten-free version 🌾", "Twice as spicy 🔥",
    "Halve the cook time ⏱️", "Budget-friendly swaps 💸", "Air-fryer version 💨",
]

private let pantryStaples = [
    "Eggs", "Rice", "Pasta", "Chicken", "Canned tomatoes", "Onions",
    "Garlic", "Potatoes", "Black beans", "Cheese", "Tortillas", "Frozen spinach",
]

private let loadingLines = [
    "Reading your cravings…", "Raiding the flavor archives…", "Balancing the macros…",
    "Sharpening the knives…", "Taste-testing (mentally)…", "Plating it beautifully…",
]

/// Mirrors `src/pages/GeneratePage.tsx`: describe / pantry / import modes,
/// remix, party-size stepper, loading/error/done states.
struct GenerateView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter
    @EnvironmentObject private var shoppingStore: ShoppingStore

    @State private var prompt = ""
    @State private var phase: Phase = .idle
    @State private var recipe: Recipe?
    @State private var errorMessage = ""
    @State private var lineIdx = 0
    @State private var loadingTask: Task<Void, Never>?

    @State private var serves = 4
    @State private var servesTouched = false
    @State private var mode: CreateMode = .describe

    @State private var importUrl = ""
    @State private var importText = ""
    @State private var pantry: [String] = []
    @State private var pantryDraft = ""

    @State private var remixSource: Recipe?
    @State private var lastImportSource: ImportSource?

    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    @State private var prepCount = 3
    @State private var prepSlots: Set<String> = ["dinner", "lunch"]
    @State private var prepWindow: PrepWindow = .hour
    @State private var prepBase = "chef"
    @State private var prepBundle: MealPrepBundle?
    @State private var addedPrep = false
    @State private var prepError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                switch phase {
                case .idle: idleContent
                case .loading: loadingContent
                case .error: errorContent
                case .done: doneContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .background(Theme.surface)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            if (phase == .idle || phase == .error),
               mode != .prep,
               (mode == .describe || remixSource != nil || phase == .error) {
                composer
            }
        }
        .onChange(of: authStore.profile?.preferences?.household_size) { _, size in
            if let size, !servesTouched { serves = size }
        }
        .onAppear {
            if let size = authStore.profile?.preferences?.household_size, !servesTouched { serves = size }
        }
        .onChange(of: deepLinks.remixRecipeId) { _, id in
            guard let id else { return }
            phase = .idle; recipe = nil; prompt = ""
            Task {
                remixSource = try? await API.fetchRecipe(id: id)
            }
            deepLinks.remixRecipeId = nil
        }
        .onChange(of: deepLinks.pendingImportURL) { _, url in
            consumePendingImport()
        }
        .onAppear {
            consumePendingImport()
            consumePendingPrep()
        }
        .onChange(of: deepLinks.pendingPrep) { _, on in
            guard on else { return }
            consumePendingPrep()
        }
        .onChange(of: prepCount) { _, n in
            if n >= 3 { prepSlots.insert("lunch") }
        }
        .onChange(of: mode) { _, m in
            if m == .prep { sanitizePrepBase() }
        }
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let data = ImageCompressor.jpegData(from: raw) {
                    await handleCapturedImage(data)
                }
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker { image in
                showCameraPicker = false
                if let data = ImageCompressor.jpegData(from: image) {
                    Task { await handleCapturedImage(data) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AI CHEF").font(.system(size: 12, weight: .heavy)).tracking(1.5).foregroundStyle(Theme.accent)
            Text("Create").font(.system(size: 32, weight: .heavy))
        }
        .padding(.top, 16)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let remixSource {
                HStack(spacing: 12) {
                    Text(remixSource.emoji ?? "").font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Remixing", systemImage: "shuffle").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                        Text(remixSource.title ?? "").font(.system(size: 15, weight: .heavy)).lineLimit(1)
                    }
                    Spacer()
                    Button {
                        self.remixSource = nil
                    } label: {
                        Image(systemName: "xmark").frame(width: 32, height: 32).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                    }
                }
                .padding(16)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
            } else {
                modeToggle
                if mode == .describe { describeHero }
            }

            if remixSource != nil || mode == .describe || mode == .pantry {
                partySizeRow
            }

            if remixSource != nil || mode == .describe {
                VStack(alignment: .leading, spacing: 8) {
                    Text(remixSource != nil ? "How should we change it?" : "Try one of these")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint)
                    FlowLayout(spacing: 8) {
                        ForEach(remixSource != nil ? remixSuggestions : suggestions, id: \.self) { s in
                            Button { Task { await submit(s) } } label: {
                                Text(s).font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Theme.raised, in: Capsule())
                                    .overlay(Capsule().stroke(Theme.line))
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
            }

            if remixSource == nil && mode == .importMode { importContent }
            if remixSource == nil && mode == .pantry { pantryContent }
            if remixSource == nil && mode == .prep { prepContent }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            ForEach([
                (CreateMode.describe, "Describe", "wand.and.stars"),
                (.pantry, "Fridge", "refrigerator"),
                (.importMode, "Import", "link"),
                (.prep, "Prep", "square.stack.3d.up"),
            ], id: \.1) { m, label, icon in
                Button { mode = m } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon).font(.system(size: 11))
                        Text(label).font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .foregroundStyle(mode == m ? Theme.content : Theme.muted)
                    .background(mode == m ? Theme.raised : .clear, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(4)
        .background(Theme.sunken, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var describeHero: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.heroGradient)
                .frame(width: 80, height: 80)
                .shadow(color: Theme.accent.opacity(0.25), radius: 20, y: 8)
                .overlay(Image(systemName: "fork.knife").font(.system(size: 32, weight: .semibold)).foregroundStyle(.white))
                .floating
            Text("What are we cooking tonight?").font(.system(size: 20, weight: .heavy))
            Text("Describe cravings, constraints, time limits or whatever's in the fridge — get a complete recipe in seconds.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var partySizeRow: some View {
        HStack {
            Label("Cooking for", systemImage: "person.2.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.content)
                .labelStyle(.custom(iconColor: Theme.accent))
            Spacer()
            HStack(spacing: 4) {
                Button { servesTouched = true; serves = max(1, serves - 1) } label: {
                    Image(systemName: "minus").frame(width: 32, height: 32).background(Theme.raised, in: Circle()).foregroundStyle(Theme.muted)
                }
                Text("\(serves) \(serves == 1 ? "person" : "people")").font(.system(size: 13, weight: .heavy)).frame(minWidth: 64)
                Button { servesTouched = true; serves = min(12, serves + 1) } label: {
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

    // MARK: - Import mode

    private var importContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bring any recipe with you 📥").font(.system(size: 20, weight: .heavy))
            Text("A blog link, a screenshot, grandma's handwritten card — the AI turns it into a clean, cookable Adaptable recipe. Free, unlimited.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)

            HStack(spacing: 8) {
                Image(systemName: "link").foregroundStyle(Theme.faint)
                TextField("Paste a recipe link…", text: $importUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button {
                    Task { await runImport(ImportSource(url: importUrl.trimmingCharacters(in: .whitespaces)), label: importUrl) }
                } label: {
                    Image(systemName: "arrow.up").foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(Theme.heroGradient, in: Circle())
                }
                .disabled(importUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(importUrl.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))

            Menu {
                Button("Take Photo") { showCameraPicker = true }
                Button("Choose from Library") { showPhotoPicker = true }
            } label: {
                HStack {
                    Image(systemName: "camera.fill").foregroundStyle(Theme.accent)
                    Text("Snap a cookbook page or screenshot").font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundStyle(Theme.content)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)

            Text("OR PASTE THE RECIPE TEXT").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint)
            TextField("Paste a caption, ingredients + steps, anything…", text: $importText, axis: .vertical)
                .lineLimit(4...8)
                .padding(14)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))

            Button {
                Task { await runImport(ImportSource(text: importText.trimmingCharacters(in: .whitespacesAndNewlines)), label: "Pasted recipe") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Import from text").font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 48)
                .foregroundStyle(Theme.surface)
                .background(Theme.content, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20)
            .opacity(importText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 ? 0.4 : 1)
        }
    }

    // MARK: - Pantry mode

    private var pantryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's in the fridge? 🧺").font(.system(size: 20, weight: .heavy))
            Text("Pick at least two ingredients — or snap the fridge — and the AI builds around what you already have.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)

            Button {
                showCameraPicker = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill").foregroundStyle(Theme.accent)
                    Text("Snap the fridge").font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 48)
                .foregroundStyle(Theme.content)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
            }
            .buttonStyle(.pressable)

            if !pantry.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(pantry, id: \.self) { item in
                        Button { pantry.removeAll { $0 == item } } label: {
                            HStack(spacing: 6) {
                                Text(item)
                                Image(systemName: "xmark").font(.system(size: 10, weight: .heavy))
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Theme.accentSoft, in: Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add an ingredient…", text: $pantryDraft)
                    .onSubmit { addPantryItem(pantryDraft) }
                Button { addPantryItem(pantryDraft) } label: {
                    Image(systemName: "plus").frame(width: 36, height: 36).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                }
                .disabled(pantryDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))

            Text("QUICK ADD").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint)
            FlowLayout(spacing: 8) {
                ForEach(pantryStaples.filter { s in !pantry.contains { $0.lowercased() == s.lowercased() } }, id: \.self) { s in
                    Button { addPantryItem(s) } label: {
                        Text("+ \(s)").font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Theme.raised, in: Capsule())
                            .overlay(Capsule().stroke(Theme.line))
                    }
                }
            }

            Button {
                Task { await submit("What can I make with what I have on hand: \(pantry.joined(separator: ", "))? Use mainly these ingredients (basic staples like oil, salt, pepper and water are available). Minimize anything I'd need to buy.") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(pantry.count < 2 ? "Pick at least 2 ingredients" : "What can I make? (\(pantry.count) items)")
                        .font(.system(size: 16, weight: .heavy))
                }
                .frame(maxWidth: .infinity).frame(height: 56)
                .foregroundStyle(.white)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .opacity(pantry.count < 2 ? 0.4 : 1)
            }
            .disabled(pantry.count < 2)
        }
    }

    private func addPantryItem(_ raw: String) {
        let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.isEmpty else { return }
        if !pantry.contains(where: { $0.lowercased() == item.lowercased() }) {
            pantry.append(item)
        }
        pantryDraft = ""
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: 80, height: 80)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(.white))
                Text(loadingLines[lineIdx]).font(.system(size: 15, weight: .bold)).id(lineIdx)
                Text(mode == .prep
                     ? "\(prepCount) leftover-friendly meals"
                     : "\u{201C}\(prompt)\u{201D}")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint).lineLimit(1).frame(maxWidth: 240)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            VStack(spacing: 12) {
                SkeletonBlock(height: 176, cornerRadius: 0)
                SkeletonBlock(height: 24, cornerRadius: 8).frame(maxWidth: 200)
                SkeletonBlock(height: 16, cornerRadius: 8)
            }
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        }
        .task {
            lineIdx = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                lineIdx = (lineIdx + 1) % loadingLines.count
            }
        }
    }

    // MARK: - Error

    private var errorContent: some View {
        VStack(spacing: 12) {
            Text("🫠").font(.system(size: 56))
            Text("The kitchen hit a snag").font(.system(size: 18, weight: .heavy))
            Text(errorMessage).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 280)
            PillButton(title: "Try again") {
                Task {
                    if mode == .prep { await buildPrep() }
                    else if let src = lastImportSource { await runImport(src, label: prompt) }
                    else { await submit() }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Done

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(prepBundle != nil
                     ? "✨ \(prepBundle!.recipes.count) leftover-friendly meals — live on the feed"
                     : "✨ Fresh out of the AI kitchen — it's live on the feed")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                Spacer()
                Button {
                    phase = .idle
                    recipe = nil
                    prompt = ""
                    remixSource = nil
                    prepBundle = nil
                    addedPrep = false
                    prepError = nil
                } label: {
                    Label("New", systemImage: "arrow.counterclockwise").font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.raised, in: Capsule())
                }
            }
            .padding(14)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let prepBundle {
                prepResult(prepBundle)
            } else if let recipe {
                RecipeContentView(recipe: recipe)
            }
        }
    }

    // MARK: - Prep mode

    private var prepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Prep complementary meals").font(.system(size: 20, weight: .heavy))
                Text("A few chips — then we generate leftover-friendly meals that share a base. Diets and allergies come from your Taste Profile.")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
            }

            prepQuestion("How many meals?")
            HStack(spacing: 8) {
                ForEach([2, 3, 4, 5], id: \.self) { n in
                    prepChip(title: "\(n)", selected: prepCount == n) { prepCount = n }
                }
            }

            prepQuestion("Which slots?", subtitle: "We’ll spread the meals across these.")
            HStack(spacing: 8) {
                ForEach([("breakfast", "Breakfast"), ("lunch", "Lunch"), ("dinner", "Dinner")], id: \.0) { id, label in
                    prepChip(title: label, selected: prepSlots.contains(id)) {
                        if prepSlots.contains(id) {
                            if prepSlots.count > 1 { prepSlots.remove(id) }
                        } else {
                            prepSlots.insert(id)
                        }
                    }
                }
            }

            prepQuestion("How long do you want to prep?")
            FlowLayout(spacing: 8) {
                ForEach(PrepWindow.allCases, id: \.rawValue) { window in
                    prepChip(title: window.label, selected: prepWindow == window) { prepWindow = window }
                }
            }

            prepQuestion("Shared base", subtitle: "Cook once, eat it several ways.")
            FlowLayout(spacing: 8) {
                ForEach(allowedPrepBases, id: \.id) { option in
                    prepChip(title: option.label, selected: prepBase == option.id) { prepBase = option.id }
                }
            }

            partySizeRow

            Button {
                Task { await buildPrep() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Build my \(prepCount) meals").font(.system(size: 16, weight: .heavy))
                }
                .frame(maxWidth: .infinity).frame(height: 56)
                .foregroundStyle(.white)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
    }

    private func prepQuestion(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Theme.faint)
            if let subtitle {
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func prepChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .foregroundStyle(selected ? Theme.surface : Theme.muted)
                .background(selected ? AnyShapeStyle(Theme.content) : AnyShapeStyle(Theme.raised), in: Capsule())
                .overlay(Capsule().stroke(Theme.line))
        }
        .buttonStyle(.pressable)
    }

    private struct PrepBaseOption: Identifiable {
        let id: String
        let label: String
    }

    private var allowedPrepBases: [PrepBaseOption] {
        let diets = (authStore.profile?.preferences?.diets ?? []).map { $0.lowercased() }
        let allergies = (authStore.profile?.preferences?.allergies ?? []).map { $0.lowercased() }
        let vegan = diets.contains { $0.contains("vegan") }
        let vegetarian = vegan || diets.contains { $0.contains("vegetarian") }
        let pescatarian = diets.contains { $0.contains("pescatarian") }
        let noFish = allergies.contains { $0.contains("fish") }
        let noEgg = allergies.contains { $0.contains("egg") }
        let noSoy = allergies.contains { $0.contains("soy") }

        var options: [PrepBaseOption] = []
        if !vegetarian && !pescatarian {
            options.append(.init(id: "chicken", label: "Chicken"))
        }
        if !vegetarian && !noFish {
            options.append(.init(id: "salmon", label: "Salmon"))
        }
        if !noSoy {
            options.append(.init(id: "tofu", label: "Tofu"))
        }
        options.append(.init(id: "beans", label: "Beans"))
        if !vegan && !noEgg {
            options.append(.init(id: "eggs", label: "Eggs"))
        }
        options.append(.init(id: "chef", label: "Chef’s choice"))
        return options
    }

    private func prepResult(_ bundle: MealPrepBundle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let prepError {
                Text(prepError)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.down)
            }
            MealPrepBundleCard(
                bundle: bundle,
                justAdded: addedPrep,
                onOpenRecipe: { deepLinks.openCreateRecipe($0) },
                onAddToWeek: { Task { await addPrepToWeek(bundle) } },
                onComplete: {}
            )
            if addedPrep {
                Button {
                    deepLinks.activeTab = .cookbook
                } label: {
                    Text("See this week")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Describe your perfect meal…", text: $prompt, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12).padding(.vertical, 10)
            Button {
                Task { await submit() }
            } label: {
                Image(systemName: "arrow.up").foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Theme.heroGradient, in: Circle())
            }
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
        }
        .padding(6)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.line))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func submit(_ text: String? = nil) async {
        let p = (text ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty, phase != .loading else { return }
        guard authStore.profile != nil else {
            errorMessage = "You need to be logged in to generate recipes."
            phase = .error
            return
        }
        if !NetworkMonitor.shared.isOnline {
            errorMessage = "You're offline — connect to generate a recipe."
            phase = .error
            return
        }
        lastImportSource = nil
        prompt = p
        phase = .loading
        recipe = nil
        prepBundle = nil
        do {
            var apiPrompt = p
            if let remixSource {
                let ingredientList = (remixSource.ingredients ?? []).prefix(10).map(\.item).joined(separator: ", ")
                apiPrompt = String(("Adapt the recipe \"\(remixSource.title ?? "")\" (key ingredients: \(ingredientList)). Requested change: \(p)").prefix(480))
            }
            let result = try await API.generateRecipe(prompt: apiPrompt, servings: serves)
            recipe = result
            phase = .done
            if let prefs = authStore.profile?.preferences {
                var next = prefs
                if remixSource != nil { next = TasteMemory.recordRemix(prompt: p, prefs: next) }
                if mode == .pantry { next = TasteMemory.recordPantry(pantry, prefs: next) }
                try? await authStore.updatePreferences(next)
            }
            deepLinks.requestFeedRefresh()
        } catch {
            print("[GenerateView] Failed to generate recipe: \(error)")
            errorMessage = AppError.friendlyMessage(for: error)
            phase = .error
        }
    }

    private func sanitizePrepBase() {
        if !allowedPrepBases.contains(where: { $0.id == prepBase }) {
            prepBase = "chef"
        }
    }

    private func consumePendingPrep() {
        guard deepLinks.pendingPrep else { return }
        deepLinks.pendingPrep = false
        remixSource = nil
        mode = .prep
        phase = .idle
        recipe = nil
        prompt = ""
        prepBundle = nil
        addedPrep = false
        prepError = nil
        sanitizePrepBase()
    }

    private func buildPrep() async {
        guard phase != .loading else { return }
        guard authStore.profile != nil else {
            errorMessage = "You need to be logged in to build a prep."
            phase = .error
            return
        }
        if !NetworkMonitor.shared.isOnline {
            errorMessage = "You're offline — connect to build this week's prep."
            phase = .error
            return
        }
        lastImportSource = nil
        prompt = "\(prepCount) leftover-friendly meals"
        phase = .loading
        recipe = nil
        prepBundle = nil
        addedPrep = false
        prepError = nil
        let slots = ["dinner", "lunch", "breakfast"].filter { prepSlots.contains($0) }
        do {
            let bundle = try await API.completeBundle(
                seedIds: [],
                kind: .sharedBase,
                targetSize: prepCount,
                slots: slots,
                prepWindow: prepWindow.rawValue,
                base: prepBase,
                servings: serves
            )
            prepBundle = bundle
            phase = .done
            deepLinks.requestFeedRefresh()
            Haptics.success()
        } catch {
            print("[GenerateView] Failed to build prep: \(error)")
            errorMessage = AppError.friendlyMessage(for: error)
            phase = .error
        }
    }

    private func addPrepToWeek(_ bundle: MealPrepBundle) async {
        guard let userId = authStore.profile?.id else { return }
        prepError = nil
        let household = authStore.profile?.preferences?.household_size ?? serves
        let sameDay = bundle.kind == .concurrent
        let parentId = bundle.recipes.first?.id
        let focus = bundle.leftover_focus.first
        for (i, recipe) in bundle.recipes.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: sameDay ? 0 : i, to: Date()) ?? Date()
            let servings = household
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
                prepError = AppError.friendlyMessage(for: error)
                Haptics.warning()
                return
            }
        }
        await shoppingStore.addBundle(bundle, userId: userId, householdSize: household)
        if let prefs = authStore.profile?.preferences {
            try? await authStore.updatePreferences(TasteMemory.recordLeftover(focus: bundle.leftover_focus, prefs: prefs))
        }
        let plans = (try? await API.fetchMealPlans(userId: userId)) ?? []
        KitchenSnapshot.refresh(from: plans)
        addedPrep = true
        Haptics.success()
    }

    private func consumePendingImport() {
        let url = deepLinks.pendingImportURL
        let text = deepLinks.pendingImportText
        deepLinks.pendingImportURL = nil
        deepLinks.pendingImportText = nil
        if let url, !url.isEmpty {
            mode = .importMode
            importUrl = url
            Task { await runImport(ImportSource(url: url), label: url) }
        } else if let text, !text.isEmpty {
            mode = .importMode
            importText = text
            Task { await runImport(ImportSource(text: text), label: "Shared recipe") }
        }
    }

    private func handleCapturedImage(_ data: Data) async {
        if mode == .pantry {
            do {
                let found = try await API.readFridge(imageBase64: data.base64EncodedString(), mimeType: "image/jpeg")
                for item in found { addPantryItem(item) }
                Haptics.success()
            } catch {
                errorMessage = AppError.friendlyMessage(for: error)
                phase = .error
            }
            return
        }
        await runImport(ImportSource(imageBase64: data.base64EncodedString(), mimeType: "image/jpeg"), label: "Photo import")
    }

    private func runImport(_ source: ImportSource, label: String) async {
        guard phase != .loading else { return }
        if !NetworkMonitor.shared.isOnline {
            errorMessage = "You're offline — connect to import a recipe."
            phase = .error
            return
        }
        lastImportSource = source
        prompt = label
        phase = .loading
        recipe = nil
        prepBundle = nil
        do {
            let result = try await API.importRecipe(source)
            recipe = result
            phase = .done
            importUrl = ""; importText = ""
            deepLinks.requestFeedRefresh()
        } catch {
            print("[GenerateView] Failed to import recipe: \(error)")
            errorMessage = AppError.friendlyMessage(for: error)
            phase = .error
        }
    }
}

private extension LabelStyle where Self == CustomLabelStyle {
    static func custom(iconColor: Color) -> CustomLabelStyle { CustomLabelStyle(iconColor: iconColor) }
}

struct CustomLabelStyle: LabelStyle {
    let iconColor: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(iconColor)
            configuration.title
        }
    }
}
