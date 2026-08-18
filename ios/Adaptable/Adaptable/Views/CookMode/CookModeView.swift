import SwiftUI
import PhotosUI

private struct RunningTimer: Identifiable {
    let step: Int
    var endsAt: Date
    let totalSeconds: Int
    var rang: Bool
    var id: Int { step }
}

private enum PhotoState: Equatable { case idle, uploading, done }

/// Full-screen guided cooking. Mirrors `src/pages/CookModePage.tsx`: one
/// step at a time, multi-timer heads-up strip, voice commands, wake-lock,
/// and a confetti finish that funnels into voting.
struct CookModeView: View {
    let recipeId: String
    let servings: Int?

    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var loadError: String?
    @State private var idx = 0
    @State private var gathered: Set<Int> = []
    @State private var sheetOpen = false
    @State private var cookRecorded = false

    @State private var timers: [RunningTimer] = []
    @State private var now = Date()

    @State private var photoState: PhotoState = .idle
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    @StateObject private var voice = VoiceCommandListener()
    @State private var voiceOn = false
    @State private var shareItem: ShareItem?
    @State private var leftoverBusy = false
    @State private var leftoverError: String?
    @State private var leftoverBundle: MealPrepBundle?
    @State private var adaptOpen = false
    @State private var adaptMissing = ""
    @State private var adaptBusy = false
    @State private var adaptError: String?
    @State private var adaptedSteps: [Int: String] = [:]
    @State private var liveActivityStarted = false

    private func loadRecipe() async {
        loadError = nil
        do {
            recipe = try await API.fetchRecipe(id: recipeId)
            if recipe == nil { loadError = "This recipe is gone." }
        } catch {
            loadError = AppError.friendlyMessage(for: error)
        }
        if let recipe,
           CookLiveActivityController.currentRecipeId == recipeId,
           let restored = CookLiveActivityController.currentStepIndex {
            let total = (recipe.steps ?? []).count
            idx = min(max(restored, 0), total + 1)
            liveActivityStarted = true
            if let endsAt = CookLiveActivityController.currentTimerEndsAt, endsAt > Date(),
               idx >= 1, idx <= total, let steps = recipe.steps, idx - 1 < steps.count {
                let seconds = DurationParser.extractTimerSeconds(steps[idx - 1].instruction)
                    ?? max(1, Int(endsAt.timeIntervalSinceNow.rounded()))
                timers = [RunningTimer(step: idx, endsAt: endsAt, totalSeconds: seconds, rang: false)]
                now = Date()
            }
        }
        applyCookCommand(deepLinks.pendingCookCommand)
    }

    private func applyCookCommand(_ command: String?) {
        guard let command, let recipe else { return }
        deepLinks.pendingCookCommand = nil
        let total = (recipe.steps ?? []).count
        if command == "next" { idx = min(idx + 1, total + 1) }
        if command == "timer" { startTimer(step: idx, total: total, recipe: recipe) }
    }

    private var factor: Double {
        guard let recipe, let servings, (recipe.servings ?? 1) > 0 else { return 1 }
        return Double(servings) / Double(recipe.servings ?? 1)
    }

    var body: some View {
        Group {
            if let recipe {
                content(recipe)
            } else if let loadError {
                Theme.surface.ignoresSafeArea().overlay {
                    EmptyStateView(emoji: "📡", title: "Couldn't load this recipe", message: loadError) {
                        VStack(spacing: 10) {
                            PillButton(title: "Retry") { Task { await loadRecipe() } }
                            PillButton(title: "Close") { dismiss() }
                        }
                    }
                }
            } else {
                Theme.surface.ignoresSafeArea().overlay(ProgressView())
            }
        }
        .task { await loadRecipe() }
        .onAppear { CookModeManager.startCookMode() }
        .onDisappear {
            voice.stop()
            CookModeManager.stopCookMode()
            CookLiveActivityController.end()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cookCommand)) { note in
            applyCookCommand(note.object as? String)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .background(Theme.surface.ignoresSafeArea())
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.activityItems)
        }
    }

    @ViewBuilder
    private func content(_ recipe: Recipe) -> some View {
        let total = (recipe.steps ?? []).count
        let isPrep = idx == 0
        let isDone = idx == total + 1
        let step = (!isPrep && !isDone) ? (recipe.steps ?? [])[idx - 1] : nil

        VStack(spacing: 0) {
            topBar(recipe: recipe, total: total, currentStep: idx, isDone: isDone)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if voiceOn {
                        Text(voice.statusMessage ?? "🎙️ Listening — say “next”, “back”, “ingredients” or “start timer”")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(voice.statusMessage != nil ? Theme.down : Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                (voice.statusMessage != nil ? Theme.down.opacity(0.12) : Theme.accentSoft),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .accessibilityLabel(voice.statusMessage ?? "Voice commands listening")
                    }

                    if isPrep { prepView(recipe: recipe) }
                    if let step { stepView(step: step, total: total) }
                    if isDone { doneView(recipe: recipe) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            if !isDone {
                bottomControls(isPrep: isPrep, idx: idx, total: total)
            }
        }
        .overlay {
            if isDone { ConfettiView().allowsHitTesting(false) }
        }
        .sheet(isPresented: $sheetOpen) { ingredientsSheet(recipe: recipe) }
        .sheet(isPresented: $adaptOpen) { adaptSheet(recipe: recipe) }
        .task(id: timers.count) { await tickTimers() }
        .onChange(of: idx) { _, newValue in
            if recipe.steps?.isEmpty == false, newValue == total + 1 { recordCookIfNeeded(recipe: recipe) }
            pushLiveActivity(recipe: recipe, total: total)
        }
        .onAppear {
            pushLiveActivity(recipe: recipe, total: total)
        }
        .onAppear {
            voice.onNext = { idx = min(idx + 1, total + 1) }
            voice.onBack = { idx = max(idx - 1, 0) }
            voice.onShowIngredients = { sheetOpen = true }
            voice.onHideIngredients = { sheetOpen = false }
            voice.onStartTimer = { startTimer(step: idx, total: total, recipe: recipe) }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker { image in
                showCameraPicker = false
                if let data = ImageCompressor.jpegData(from: image) {
                    Task { await uploadPhoto(data, recipe: recipe) }
                }
            }.ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let data = ImageCompressor.jpegData(from: raw) {
                    await uploadPhoto(data, recipe: recipe)
                }
            }
        }
    }

    // MARK: - Top bar

    private func topBar(recipe: Recipe, total: Int, currentStep: Int, isDone: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 40, height: 40).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                }
                VStack(spacing: 6) {
                    Text("\(recipe.emoji ?? "") \(recipe.title ?? "")").font(.system(size: 13, weight: .bold)).lineLimit(1)
                    HStack(spacing: 3) {
                        ForEach(0...total, id: \.self) { i in
                            Capsule().fill(i <= currentStep - (isDone ? 1 : 0) && currentStep > 0 ? Theme.accent : Theme.line).frame(height: 4)
                        }
                    }
                }
                Button {
                    voiceOn.toggle()
                    if voiceOn { voice.start() } else { voice.stop() }
                } label: {
                    Image(systemName: voiceOn ? "mic.fill" : "mic.slash")
                        .frame(width: 40, height: 40)
                        .background(voiceOn ? Theme.accent : Theme.sunken, in: Circle())
                        .foregroundStyle(voiceOn ? .white : Theme.muted)
                }
                Button { sheetOpen = true } label: {
                    Image(systemName: "list.bullet.rectangle").frame(width: 40, height: 40).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                }
            }

            let otherTimers = timers.filter { $0.step != currentStep }
            if !otherTimers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(otherTimers) { t in
                            let left = max(0, Int(t.endsAt.timeIntervalSince(now).rounded()))
                            let finished = left <= 0
                            Button {
                                if finished { timers.removeAll { $0.step == t.step } } else { self.idx = t.step }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "timer")
                                    Text("Step \(t.step) · \(finished ? "Done ✓" : DurationParser.formatClock(left))")
                                }
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(finished ? .white : Theme.accent)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(finished ? Theme.accent : Theme.accentSoft, in: Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Prep

    private func prepView(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MISE EN PLACE").font(.system(size: 12, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.accent)
            Text("Gather everything first").font(.system(size: 26, weight: .heavy))
            Text((servings != nil && servings != recipe.servings) ? "Scaled for \(servings!) servings. Tap items as you set them out." : "For \(recipe.servings ?? 1) servings. Tap items as you set them out.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)

            VStack(spacing: 0) {
                ForEach(Array((recipe.ingredients ?? []).enumerated()), id: \.offset) { i, ing in
                    if i > 0 { Divider().overlay(Theme.line) }
                    Button {
                        if gathered.contains(i) { gathered.remove(i) } else { gathered.insert(i) }
                    } label: {
                        HStack(spacing: 12) {
                            Circle().strokeBorder(gathered.contains(i) ? Theme.accent : Theme.line, lineWidth: 2)
                                .background(Circle().fill(gathered.contains(i) ? Theme.accent : .clear))
                                .frame(width: 22, height: 22)
                                .overlay(gathered.contains(i) ? Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.white) : nil)
                            Text(ing.item).font(.system(size: 15, weight: .semibold)).strikethrough(gathered.contains(i))
                            Spacer()
                            Text(Quantity.scale(ing.quantity, factor: factor)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                        }
                        .opacity(gathered.contains(i) ? 0.45 : 1)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Step

    private func stepView(step: RecipeStep, total: Int) -> some View {
        let timerSeconds = DurationParser.extractTimerSeconds(step.instruction)
        let currentTimer = timers.first { $0.step == idx }

        return VStack(alignment: .leading, spacing: 16) {
            Text("STEP \(idx) OF \(total)").font(.system(size: 12, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.accent)
            Text(adaptedSteps[idx] ?? step.instruction).font(.system(size: 24, weight: .bold))

            Button {
                adaptOpen = true
            } label: {
                Label("I'm out of something — adapt this step", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.pressable)

            if let tip = step.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Theme.accent)
                    Text(tip).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.accent)
                }
                .padding(14)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let timerSeconds {
                HStack(spacing: 12) {
                    Circle().fill(Theme.accentSoft).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "timer").foregroundStyle(Theme.accent))
                    VStack(alignment: .leading, spacing: 2) {
                        let remaining = currentTimer.map { max(0, Int($0.endsAt.timeIntervalSince(now).rounded())) } ?? timerSeconds
                        Text(DurationParser.formatClock(remaining)).font(.system(size: 20, weight: .heavy)).monospacedDigit()
                        Text(timerCaption(currentTimer: currentTimer))
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint)
                    }
                    Spacer()
                    if currentTimer == nil {
                        Button {
                            if let recipe {
                                startTimer(step: idx, total: total, recipe: recipe)
                            }
                        } label: {
                            Image(systemName: "play.fill").foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(Theme.heroGradient, in: Circle())
                        }
                    } else {
                        Button {
                            timers.removeAll { $0.step == idx }
                        } label: {
                            Image(systemName: "arrow.counterclockwise").foregroundStyle(Theme.muted)
                                .frame(width: 44, height: 44).background(Theme.raised, in: Circle()).overlay(Circle().stroke(Theme.line))
                        }
                    }
                }
                .padding(14)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
            }
        }
        .padding(.vertical, 8)
    }

    private func timerCaption(currentTimer: RunningTimer?) -> String {
        guard let currentTimer else { return "Step timer" }
        return currentTimer.endsAt <= now ? "Time's up!" : "Running — keeps going between steps"
    }

    private func startTimer(step: Int, total: Int, recipe: Recipe) {
        guard step >= 1, step <= total else { return }
        guard !timers.contains(where: { $0.step == step }) else { return }
        guard let steps = recipe.steps, step - 1 < steps.count,
              let seconds = DurationParser.extractTimerSeconds(steps[step - 1].instruction) else { return }
        timers.append(RunningTimer(step: step, endsAt: Date().addingTimeInterval(Double(seconds)), totalSeconds: seconds, rang: false))
        Alarm.scheduleTimerNotification(seconds: seconds, step: step)
        Haptics.light()
        now = Date()
        pushLiveActivity(recipe: recipe, total: total)
    }

    private func tickTimers() async {
        while !timers.isEmpty && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 400_000_000)
            now = Date()
            for i in timers.indices where !timers[i].rang && timers[i].endsAt <= now {
                timers[i].rang = true
                Alarm.ring()
            }
        }
    }

    // MARK: - Done

    private func doneView(recipe: Recipe) -> some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Gradients.cover(for: recipe.id))
                .frame(width: 96, height: 96)
                .overlay(Image(systemName: "party.popper.fill").font(.system(size: 40)).foregroundStyle(.white))
            Text("Chef's kiss! 🤌").font(.system(size: 26, weight: .heavy))
            Text("You just cooked \(recipe.title ?? "this dish"). How did it turn out? Your vote shapes the community feed.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 280)
            Text("🍳 You're cook #\(Format.compactCount((recipe.cook_count ?? 0) + 1)) — this fuels the Trending feed")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                .padding(.horizontal, 16).padding(.vertical, 8).background(Theme.accentSoft, in: Capsule())

            HStack(spacing: 12) {
                VotePillView(recipeId: recipe.id, baseCount: recipe.net_upvotes ?? 0, size: .lg)
                SaveButtonView(recipeId: recipe.id, variant: .bar)
            }
            .frame(maxWidth: 320)

            Button {
                shareCooked(recipe)
            } label: {
                Label("Share this recipe", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: 320).frame(height: 48)
                    .foregroundStyle(Theme.content)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Share this recipe")

            if !SupabaseManager.isDemo {
                Menu {
                    Button("Take Photo") { showCameraPicker = true }
                    Button("Choose from Library") { showPhotoPicker = true }
                } label: {
                    HStack(spacing: 8) {
                        switch photoState {
                        case .uploading: ProgressView()
                        case .done:
                            Image(systemName: "checkmark")
                            Text("Photo shared with the community")
                        case .idle:
                            Image(systemName: "camera.fill").foregroundStyle(Theme.accent)
                            Text("Show off your plate 📸")
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: 320).frame(height: 48)
                    .foregroundStyle(photoState == .done ? Theme.accent : Theme.content)
                    .background(photoState == .done ? Theme.accentSoft : Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(photoState == .done ? Theme.accent : Theme.line))
                }
                .disabled(photoState == .uploading || photoState == .done)
                .accessibilityLabel("Share a photo of your plate")
            }

            leftoverBlock(recipe)

            Button("Back to Discover") { dismiss() }
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                .accessibilityLabel("Back to Discover")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func shareCooked(_ recipe: Recipe) {
        Task {
            Haptics.success()
            let serves = servings ?? recipe.servings ?? 2
            let payload = RecipeShare.build(recipe: recipe, servings: serves)
            let card = await RecipeShare.cardImage(recipe: recipe, servings: serves)
            shareItem = ShareItem(text: payload.text, url: payload.url, image: card)
        }
    }

    private func leftoverBlock(_ recipe: Recipe) -> some View {
        VStack(spacing: 10) {
            if let leftoverBundle {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOMORROW FROM LEFTOVERS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(Theme.accent)
                    ForEach(leftoverBundle.recipes.filter { $0.id != recipe.id }) { r in
                        Button {
                            let id = r.id
                            dismiss()
                            deepLinks.openCookbookRecipe(id)
                        } label: {
                            Text("\(r.emoji ?? "🍽️") \(r.title ?? "Leftover meal")")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.content)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(leftoverBundle.headline)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .padding(14)
                .frame(maxWidth: 320, alignment: .leading)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Button {
                    Task { await generateLeftover(from: recipe) }
                } label: {
                    HStack(spacing: 8) {
                        if leftoverBusy { ProgressView().tint(.white) }
                        else { Image(systemName: "sparkles") }
                        Text(leftoverBusy ? "Writing tomorrow's meal…" : leftoverCta(recipe))
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .frame(maxWidth: 320).frame(height: 48)
                    .foregroundStyle(.white)
                    .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable)
                .disabled(leftoverBusy)
            }
            if let leftoverError {
                Text(leftoverError).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.down)
            }
        }
    }

    private func leftoverCta(_ recipe: Recipe) -> String {
        if let focus = MealPrepBundles.leftoverFocus([recipe]).first {
            return "Generate tomorrow from leftover \(focus)"
        }
        return "Generate tomorrow from these leftovers"
    }

    private func generateLeftover(from recipe: Recipe) async {
        leftoverBusy = true
        leftoverError = nil
        do {
            let bundle = try await API.completeBundle(seedIds: [recipe.id], kind: .sharedBase, targetSize: 2)
            leftoverBundle = bundle
            if let userId = authStore.profile?.id {
                let tomorrow = Format.localISODate(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                let servings = authStore.profile?.preferences?.household_size ?? recipe.servings ?? 2
                let focus = bundle.leftover_focus.first
                for child in bundle.recipes where child.id != recipe.id {
                    try? await API.addMealPlan(
                        userId: userId,
                        recipeId: child.id,
                        planDate: tomorrow,
                        servings: servings,
                        leftoverOf: recipe.id,
                        leftoverFocus: focus
                    )
                }
            }
            if let prefs = authStore.profile?.preferences {
                try? await authStore.updatePreferences(TasteMemory.recordLeftover(focus: bundle.leftover_focus, prefs: prefs))
            }
            Haptics.success()
        } catch {
            leftoverError = AppError.friendlyMessage(for: error)
        }
        leftoverBusy = false
    }

    private func adaptSheet(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(Theme.line).frame(width: 40, height: 5).frame(maxWidth: .infinity)
            Text("Adapt this step").font(.system(size: 18, weight: .heavy))
            Text("What did you run out of? We'll rewrite the step in place — the recipe stays yours.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)
            TextField("e.g. heavy cream", text: $adaptMissing)
                .padding(12)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if let adaptError {
                Text(adaptError).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.down)
            }
            Button {
                Task { await runAdapt(recipe: recipe) }
            } label: {
                HStack {
                    if adaptBusy { ProgressView().tint(.white) }
                    Text(adaptBusy ? "Adapting…" : "Rewrite this step").font(.system(size: 15, weight: .heavy))
                }
                .frame(maxWidth: .infinity).frame(height: 48)
                .foregroundStyle(.white)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(adaptBusy || adaptMissing.trimmingCharacters(in: .whitespaces).count < 2)
        }
        .padding(20)
        .presentationDetents([.height(280)])
    }

    private func runAdapt(recipe: Recipe) async {
        adaptBusy = true
        adaptError = nil
        do {
            var draft = recipe
            if let rewritten = adaptedSteps[idx], var steps = draft.steps, let i = steps.firstIndex(where: { $0.step == idx }) {
                steps[i].instruction = rewritten
                draft.steps = steps
            }
            let result = try await API.adaptStep(recipe: draft, step: idx, missing: adaptMissing)
            adaptedSteps[idx] = result.instruction
            adaptOpen = false
            adaptMissing = ""
            adaptError = nil
            Haptics.success()
        } catch {
            adaptError = AppError.friendlyMessage(for: error)
        }
        adaptBusy = false
    }

    private func pushLiveActivity(recipe: Recipe, total: Int) {
        let label: String
        if idx == 0 { label = "Mise en place" }
        else if idx > total { label = "Done" }
        else { label = "Step \(idx) of \(total)" }
        let timer = timers.first(where: { $0.step == idx && $0.endsAt > Date() })?.endsAt
        if liveActivityStarted {
            CookLiveActivityController.update(stepLabel: label, step: idx, total: total, timerEndsAt: timer)
        } else if CookLiveActivityController.start(recipe: recipe, stepLabel: label, step: idx, total: total, timerEndsAt: timer) != nil {
            liveActivityStarted = true
        }
    }

    private func recordCookIfNeeded(recipe: Recipe) {
        guard !cookRecorded, let userId = authStore.profile?.id else { return }
        cookRecorded = true
        Task {
            try? await API.recordCook(userId: userId, recipeId: recipe.id)
            if let prefs = authStore.profile?.preferences {
                try? await authStore.updatePreferences(TasteMemory.recordCook(recipe, prefs: prefs))
            }
        }
    }

    private func uploadPhoto(_ data: Data, recipe: Recipe) async {
        guard let userId = authStore.profile?.id, photoState != .uploading else { return }
        photoState = .uploading
        do {
            _ = try await API.uploadCookPhoto(userId: userId, recipeId: recipe.id, imageData: data)
            photoState = .done
        } catch {
            photoState = .idle
        }
    }

    // MARK: - Bottom controls

    private func bottomControls(isPrep: Bool, idx: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            if idx > 0 {
                Button {
                    self.idx = max(self.idx - 1, 0)
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .foregroundStyle(Theme.muted)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
                }
                .accessibilityLabel("Previous step")
            }
            Button {
                self.idx = min(self.idx + 1, total + 1)
            } label: {
                HStack(spacing: 8) {
                    Text(isPrep ? "Let's cook" : (idx == total ? "Finish 🎉" : "Next step")).font(.system(size: 16, weight: .heavy))
                    if !isPrep && idx < total { Image(systemName: "chevron.right") }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .accessibilityLabel(isPrep ? "Start cooking" : (idx == total ? "Finish cooking" : "Next step"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Ingredients sheet

    private func ingredientsSheet(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(Theme.line).frame(width: 40, height: 5).frame(maxWidth: .infinity)
            Text("Ingredients").font(.system(size: 18, weight: .heavy))
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array((recipe.ingredients ?? []).enumerated()), id: \.offset) { i, ing in
                        if i > 0 { Divider().overlay(Theme.line) }
                        HStack {
                            Text(ing.item).font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text(Quantity.scale(ing.quantity, factor: factor)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
    }
}

/// Lightweight confetti burst using SwiftUI particles.
private struct ConfettiView: View {
    private let colors: [Color] = [.orange, .pink, .green, .blue, .yellow, .purple]
    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<40, id: \.self) { i in
                    Rectangle()
                        .fill(colors[i % colors.count])
                        .frame(width: 7, height: 3)
                        .position(
                            x: CGFloat.random(in: 0...max(proxy.size.width, 1)),
                            y: animate ? proxy.size.height + 40 : -20
                        )
                        .rotationEffect(.degrees(animate ? Double.random(in: 200...800) : 0))
                        .animation(.easeIn(duration: Double.random(in: 1.8...3.2)).delay(Double.random(in: 0...0.6)), value: animate)
                }
            }
        }
        .onAppear { animate = true }
    }
}
