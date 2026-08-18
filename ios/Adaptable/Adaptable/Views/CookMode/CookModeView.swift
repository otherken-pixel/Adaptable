import SwiftUI
import PhotosUI

private struct RunningTimer: Identifiable {
    let specId: String
    let step: Int
    let label: String
    var endsAt: Date
    let totalSeconds: Int
    var rang: Bool
    var id: String { specId }
}

private enum PhotoState: Equatable { case idle, uploading, done }

/// Full-screen guided cooking. One step at a time with per-step quantities,
/// multi-timers, voice commands, wake-lock, and a two-column layout on
/// regular-width scenes (iPad / large Split View).
struct CookModeView: View {
    let recipeId: String
    let servings: Int?

    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var recipe: Recipe?
    @State private var idx = 0
    @State private var gathered: Set<Int> = []
    @State private var sheetOpen = false
    @State private var adaptOpen = false
    @State private var cookRecorded = false
    @State private var substitutions: [String: String] = [:]
    @State private var containerWidth: CGFloat = 390

    @State private var timers: [RunningTimer] = []
    @State private var now = Date()

    @State private var photoState: PhotoState = .idle
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    @StateObject private var voice = VoiceCommandListener()
    @State private var voiceOn = false
    @State private var shareItem: ShareItem?

    private var factor: Double {
        guard let recipe, let servings, (recipe.servings ?? 1) > 0 else { return 1 }
        return Double(servings) / Double(recipe.servings ?? 1)
    }

    private var isSplit: Bool {
        containerWidth >= 700 && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if let recipe {
                content(recipe)
            } else {
                Theme.surface.ignoresSafeArea().overlay(ProgressView())
            }
        }
        .task {
            recipe = try? await API.fetchRecipe(id: recipeId)
        }
        .onAppear { CookModeManager.startCookMode() }
        .onDisappear {
            voice.stop()
            CookModeManager.stopCookMode()
            CookTimerLiveActivity.endAll()
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .background(Theme.surface.ignoresSafeArea())
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.activityItems)
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: CookWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(CookWidthKey.self) { containerWidth = $0 }
    }

    @ViewBuilder
    private func content(_ recipe: Recipe) -> some View {
        let total = (recipe.steps ?? []).count
        let isPrep = idx == 0
        let isDone = idx == total + 1
        let step = (!isPrep && !isDone) ? (recipe.steps ?? [])[idx - 1] : nil
        let next = (!isPrep && !isDone && idx < total) ? (recipe.steps ?? [])[idx] : nil
        let resolved = step.map {
            StepResolver.resolve(
                step: $0,
                number: idx,
                total: total,
                recipe: recipe,
                factor: factor,
                substitutions: substitutions,
                nextStep: next
            )
        }

        VStack(spacing: 0) {
            topBar(recipe: recipe, total: total, currentStep: idx, isDone: isDone)

            if isPrep {
                ScrollView {
                    prepView(recipe: recipe)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let resolved {
                stepChrome(recipe: recipe, resolved: resolved)
            } else if isDone {
                ScrollView {
                    doneView(recipe: recipe)
                        .padding(.horizontal, 20)
                }
            }

            if !isDone {
                bottomControls(isPrep: isPrep, idx: idx, total: total)
            }
        }
        .overlay {
            if isDone { ConfettiView().allowsHitTesting(false) }
        }
        .sheet(isPresented: $sheetOpen) { ingredientsSheet(recipe: recipe) }
        .sheet(isPresented: $adaptOpen) {
            AdaptStepSheet(
                recipeTitle: recipe.title ?? "this recipe",
                ingredients: resolved?.ingredients ?? [],
                substitutions: substitutions,
                onApply: { from, to in
                    applySubstitution(from: from, to: to)
                    adaptOpen = false
                },
                    onAskAI: { prompt in
                    adaptOpen = false
                    deepLinks.openRemix(recipe.id, prompt: prompt)
                    dismiss()
                },
                onDismiss: { adaptOpen = false }
            )
        }
        .task(id: timers.count) { await tickTimers() }
        .onChange(of: idx) { _, newValue in
            if recipe.steps?.isEmpty == false, newValue == total + 1 { recordCookIfNeeded(recipe: recipe) }
        }
        .onChange(of: timers.map(\.id).joined()) { _, _ in
            syncLiveActivity(recipe: recipe, total: total)
        }
        .onAppear {
            voice.onNext = { idx = min(idx + 1, total + 1) }
            voice.onBack = { idx = max(idx - 1, 0) }
            voice.onShowIngredients = { sheetOpen = true }
            voice.onHideIngredients = { sheetOpen = false }
            voice.onStartTimer = { startTimersForCurrentStep() }
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

    // MARK: - Step layout (phone stacked / iPad split)

    @ViewBuilder
    private func stepChrome(recipe: Recipe, resolved: ResolvedStep) -> some View {
        let servingsCount = servings ?? recipe.servings ?? 1
        let totalMinutes = (recipe.prep_time_minutes ?? 0) + (recipe.cook_time_minutes ?? 0)

        if isSplit {
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    stepPrimary(recipe: recipe, resolved: resolved, servingsCount: servingsCount, totalMinutes: totalMinutes, includeIngredients: false)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .frame(maxWidth: 720, alignment: .leading)
                }
                Divider()
                ScrollView {
                    inspector(recipe: recipe, resolved: resolved)
                        .padding(20)
                }
                .frame(minWidth: 280, maxWidth: 400)
                .background(Theme.sunken.opacity(0.35))
            }
        } else {
            ScrollView {
                stepPrimary(recipe: recipe, resolved: resolved, servingsCount: servingsCount, totalMinutes: totalMinutes, includeIngredients: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func stepPrimary(
        recipe: Recipe,
        resolved: ResolvedStep,
        servingsCount: Int,
        totalMinutes: Int,
        includeIngredients: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if voiceOn {
                Text(voice.statusMessage ?? "🎙️ Listening — say “next”, “back”, “ingredients” or “start timer”")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(voice.statusMessage != nil ? Theme.down : Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        (voice.statusMessage != nil ? Theme.down.opacity(0.12) : Theme.accentSoft),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .accessibilityLabel(voice.statusMessage ?? "Voice commands listening")
            }

            Text("STEP \(resolved.number) OF \(resolved.total)")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.accent)

            CookContextBar(
                servings: servingsCount,
                totalMinutes: totalMinutes,
                temperature: resolved.temperature,
                equipment: resolved.equipment
            )

            CookActionList(actions: resolved.actions)

            if includeIngredients, !resolved.ingredients.isEmpty {
                CookStepIngredientList(ingredients: resolved.ingredients, gathered: gathered, onToggle: toggleIngredient)
            }

            if !resolved.timers.isEmpty {
                VStack(spacing: 10) {
                    ForEach(resolved.timers) { spec in
                        timerCard(spec: spec, step: resolved.number, recipe: recipe)
                    }
                }
            }

            if let lookFor = resolved.lookFor {
                CookCueCard(systemImage: "eye", title: "LOOK FOR", bodyText: lookFor)
            }
            if let yieldNote = resolved.yieldNote {
                CookCueCard(systemImage: "tray.and.arrow.down", title: "SAVE THIS", bodyText: yieldNote, accented: false)
            }
            if let safety = resolved.safety {
                CookCueCard(systemImage: "exclamationmark.triangle.fill", title: "WATCH", bodyText: safety)
            }
            if !isSplit, let meanwhile = resolved.meanwhile {
                CookCueCard(systemImage: "arrow.left.arrow.right", title: "MEANWHILE", bodyText: meanwhile)
            }
            if let tip = resolved.tip {
                CookCueCard(systemImage: "lightbulb.fill", title: "TIP", bodyText: tip)
            }

            Button { adaptOpen = true } label: {
                Label("I’m out of something — adapt this step", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Substitute an ingredient for this step")

            if !substitutions.isEmpty {
                Text("Swapped: " + substitutions.map { "\($0.key) → \($0.value)" }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 8)
    }

    private func inspector(recipe: Recipe, resolved: ResolvedStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            RecipeCoverView(
                recipeId: recipe.id,
                emoji: recipe.emoji,
                imageUrl: recipe.image_url,
                cuisine: recipe.cuisine,
                height: 140,
                emojiSize: 56
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

            if !resolved.ingredients.isEmpty {
                CookStepIngredientList(ingredients: resolved.ingredients, gathered: gathered, onToggle: toggleIngredient)
            }

            if let next = resolved.meanwhile {
                CookCueCard(systemImage: "arrow.left.arrow.right", title: "MEANWHILE", bodyText: next)
            }

            fullListPeek(recipe: recipe)
        }
    }

    private func fullListPeek(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FULL LIST")
                .font(.caption.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(Theme.faint)
            ForEach(Array((recipe.ingredients ?? []).enumerated()), id: \.offset) { i, ing in
                HStack {
                    Text(substitutions[ing.item] ?? ing.item)
                        .font(.caption.weight(.semibold))
                        .strikethrough(gathered.contains(i))
                    Spacer()
                    Text(Quantity.scale(ing.quantity, factor: factor))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                .opacity(gathered.contains(i) ? 0.45 : 1)
            }
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
    }

    private func timerCard(spec: ExtractedTimer, step: Int, recipe: Recipe) -> some View {
        let specId = timerId(step: step, spec: spec)
        let current = timers.first { $0.specId == specId }
        let remaining = current.map { max(0, Int($0.endsAt.timeIntervalSince(now).rounded())) } ?? spec.seconds
        let running = current != nil
        let finished = current.map { $0.endsAt <= now } ?? false
        return CookTimerCard(
            spec: spec,
            remaining: remaining,
            running: running,
            finished: finished,
            onStart: { startTimer(spec: spec, step: step, recipe: recipe) },
            onReset: { timers.removeAll { $0.specId == specId } }
        )
    }

    // MARK: - Top bar

    private func topBar(recipe: Recipe, total: Int, currentStep: Int, isDone: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("Exit cook mode")
                VStack(spacing: 6) {
                    Text("\(recipe.emoji ?? "") \(recipe.title ?? "")").font(.subheadline.weight(.bold)).lineLimit(1)
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
                        .frame(width: 44, height: 44)
                        .background(voiceOn ? Theme.accent : Theme.sunken, in: Circle())
                        .foregroundStyle(voiceOn ? .white : Theme.muted)
                }
                .accessibilityLabel(voiceOn ? "Disable voice control" : "Enable voice control")
                Button { sheetOpen = true } label: {
                    Image(systemName: "list.bullet.rectangle").frame(width: 44, height: 44).background(Theme.sunken, in: Circle()).foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("Show ingredients")
            }

            let otherTimers = timers.filter { $0.step != currentStep }
            if !otherTimers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(otherTimers) { t in
                            let left = max(0, Int(t.endsAt.timeIntervalSince(now).rounded()))
                            let finished = left <= 0
                            Button {
                                if finished { timers.removeAll { $0.specId == t.specId } } else { self.idx = t.step }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "timer")
                                    Text("\(t.label) · \(finished ? "Done ✓" : DurationParser.formatClock(left))")
                                }
                                .font(.caption.weight(.heavy).monospacedDigit())
                                .foregroundStyle(finished ? .white : Theme.accent)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(finished ? Theme.accent : Theme.accentSoft, in: Capsule())
                            }
                            .accessibilityLabel("\(t.label) timer, \(finished ? "done" : DurationParser.formatClock(left))")
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
            Text("MISE EN PLACE").font(.caption.weight(.heavy)).tracking(1.2).foregroundStyle(Theme.accent)
            Text("Gather everything first").font(.title.weight(.heavy))
            Text((servings != nil && servings != recipe.servings) ? "Scaled for \(servings!) servings. Tap items as you set them out." : "For \(recipe.servings ?? 1) servings. Tap items as you set them out.")
                .font(.subheadline).foregroundStyle(Theme.muted)

            VStack(spacing: 0) {
                ForEach(Array((recipe.ingredients ?? []).enumerated()), id: \.offset) { i, ing in
                    if i > 0 { Divider().overlay(Theme.line) }
                    Button {
                        if gathered.contains(i) { gathered.remove(i) } else { gathered.insert(i) }
                    } label: {
                        HStack(spacing: 12) {
                            Circle().strokeBorder(gathered.contains(i) ? Theme.accent : Theme.line, lineWidth: 2)
                                .background(Circle().fill(gathered.contains(i) ? Theme.accent : .clear))
                                .frame(width: 24, height: 24)
                                .overlay(gathered.contains(i) ? Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.white) : nil)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(substitutions[ing.item] ?? ing.item)
                                    .font(.body.weight(.semibold))
                                    .strikethrough(gathered.contains(i))
                                if let note = ing.note, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(Theme.faint)
                                }
                            }
                            Spacer()
                            Text(Quantity.scale(ing.quantity, factor: factor))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.muted)
                        }
                        .opacity(gathered.contains(i) ? 0.45 : 1)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
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

    // MARK: - Done

    private func doneView(recipe: Recipe) -> some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Gradients.cover(for: recipe.id))
                .frame(width: 96, height: 96)
                .overlay(Image(systemName: "party.popper.fill").font(.system(size: 40)).foregroundStyle(.white))
            Text("Chef's kiss! 🤌").font(.title.weight(.heavy))
            Text("You just cooked \(recipe.title ?? "this dish"). How did it turn out? Your vote shapes the community feed.")
                .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 280)
            Text("🍳 You're cook #\(Format.compactCount((recipe.cook_count ?? 0) + 1)) — this fuels the Trending feed")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
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
                    .font(.subheadline.weight(.bold))
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
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: 320).frame(height: 48)
                    .foregroundStyle(photoState == .done ? Theme.accent : Theme.content)
                    .background(photoState == .done ? Theme.accentSoft : Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(photoState == .done ? Theme.accent : Theme.line))
                }
                .disabled(photoState == .uploading || photoState == .done)
                .accessibilityLabel("Share a photo of your plate")
            }

            Button("Back to Discover") { dismiss() }
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.muted)
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

    private func recordCookIfNeeded(recipe: Recipe) {
        guard !cookRecorded, let userId = authStore.profile?.id else { return }
        cookRecorded = true
        Task { try? await API.recordCook(userId: userId, recipeId: recipe.id) }
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
                    Text(isPrep ? "Let's cook" : (idx == total ? "Finish 🎉" : "Next step")).font(.body.weight(.heavy))
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
            Text("Ingredients").font(.title3.weight(.heavy))
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array((recipe.ingredients ?? []).enumerated()), id: \.offset) { i, ing in
                        if i > 0 { Divider().overlay(Theme.line) }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(substitutions[ing.item] ?? ing.item).font(.body.weight(.semibold))
                                if let note = ing.note { Text(note).font(.caption).foregroundStyle(Theme.faint) }
                            }
                            Spacer()
                            Text(Quantity.scale(ing.quantity, factor: factor))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 12)
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

    // MARK: - Timers

    private func timerId(step: Int, spec: ExtractedTimer) -> String {
        "\(step)|\(spec.label)|\(spec.seconds)"
    }

    private func startTimer(spec: ExtractedTimer, step: Int, recipe: Recipe) {
        let specId = timerId(step: step, spec: spec)
        guard !timers.contains(where: { $0.specId == specId }) else { return }
        timers.append(RunningTimer(
            specId: specId,
            step: step,
            label: spec.label,
            endsAt: Date().addingTimeInterval(Double(spec.seconds)),
            totalSeconds: spec.seconds,
            rang: false
        ))
        Alarm.scheduleTimerNotification(seconds: spec.seconds, step: step, label: spec.label, recipeTitle: recipe.title)
        Haptics.light()
        now = Date()
        syncLiveActivity(recipe: recipe, total: (recipe.steps ?? []).count)
    }

    private func startAllTimers(for resolved: ResolvedStep, recipe: Recipe) {
        for spec in resolved.timers {
            startTimer(spec: spec, step: resolved.number, recipe: recipe)
        }
    }

    private func startTimersForCurrentStep() {
        guard let recipe else { return }
        let total = (recipe.steps ?? []).count
        guard idx >= 1, idx <= total else { return }
        let step = (recipe.steps ?? [])[idx - 1]
        let next = idx < total ? (recipe.steps ?? [])[idx] : nil
        let resolved = StepResolver.resolve(
            step: step,
            number: idx,
            total: total,
            recipe: recipe,
            factor: factor,
            substitutions: substitutions,
            nextStep: next
        )
        startAllTimers(for: resolved, recipe: recipe)
    }

    private func tickTimers() async {
        while !timers.isEmpty && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 400_000_000)
            now = Date()
            for i in timers.indices where !timers[i].rang && timers[i].endsAt <= now {
                timers[i].rang = true
                Alarm.ring()
                if let recipe {
                    syncLiveActivity(recipe: recipe, total: (recipe.steps ?? []).count)
                }
            }
        }
    }

    private func syncLiveActivity(recipe: Recipe, total: Int) {
        CookTimerLiveActivity.sync(
            recipeTitle: recipe.title ?? "Cooking",
            emoji: recipe.emoji ?? "🍳",
            timers: timers.map { (label: $0.label, endsAt: $0.endsAt, step: $0.step, totalSeconds: $0.totalSeconds) },
            totalSteps: total
        )
    }

    private func toggleIngredient(_ ing: StepIngredientUse) {
        guard let idx = ing.recipeIndex else { return }
        if gathered.contains(idx) { gathered.remove(idx) } else { gathered.insert(idx) }
        Haptics.selection()
    }

    private func applySubstitution(from: String, to: String) {
        if to.lowercased() == "omit" {
            substitutions[from] = "\(from) (skipped)"
        } else {
            substitutions[from] = to
        }
        Haptics.success()
    }
}

private struct CookWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 390
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
