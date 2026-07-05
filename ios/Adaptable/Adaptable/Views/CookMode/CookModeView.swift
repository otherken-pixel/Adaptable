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
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
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

    private var factor: Double {
        guard let recipe, let servings, recipe.servings > 0 else { return 1 }
        return Double(servings) / Double(recipe.servings)
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
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            voice.stop()
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .background(Theme.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func content(_ recipe: Recipe) -> some View {
        let total = recipe.steps.count
        let isPrep = idx == 0
        let isDone = idx == total + 1
        let step = (!isPrep && !isDone) ? recipe.steps[idx - 1] : nil

        VStack(spacing: 0) {
            topBar(recipe: recipe, total: total, currentStep: idx, isDone: isDone)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if voiceOn {
                        Text("🎙️ Listening — say \u{201C}next\u{201D}, \u{201C}back\u{201D}, \u{201C}ingredients\u{201D} or \u{201C}start timer\u{201D}")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
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
        .task(id: timers.count) { await tickTimers() }
        .onChange(of: idx) { _, newValue in
            if recipe.steps.isEmpty == false, newValue == total + 1 { recordCookIfNeeded(recipe: recipe) }
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
                if let data = image.jpegData(compressionQuality: 0.8) {
                    Task { await uploadPhoto(data, recipe: recipe) }
                }
            }.ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
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
                    Text("\(recipe.emoji) \(recipe.title)").font(.system(size: 13, weight: .bold)).lineLimit(1)
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
            Text((servings != nil && servings != recipe.servings) ? "Scaled for \(servings!) servings. Tap items as you set them out." : "For \(recipe.servings) servings. Tap items as you set them out.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, ing in
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
            Text(step.instruction).font(.system(size: 24, weight: .bold))

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
                        Text(currentTimer == nil ? "Step timer" : (currentTimer!.endsAt <= now ? "Time's up!" : "Running — keeps going between steps"))
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint)
                    }
                    Spacer()
                    if currentTimer == nil {
                        Button {
                            startTimer(step: idx, total: total, recipe: recipe!)
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

    private func startTimer(step: Int, total: Int, recipe: Recipe) {
        guard step >= 1, step <= total else { return }
        guard !timers.contains(where: { $0.step == step }) else { return }
        guard let seconds = DurationParser.extractTimerSeconds(recipe.steps[step - 1].instruction) else { return }
        timers.append(RunningTimer(step: step, endsAt: Date().addingTimeInterval(Double(seconds)), totalSeconds: seconds, rang: false))
        now = Date()
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
            Text("You just cooked **\(recipe.title)**. How did it turn out? Your vote shapes the community feed.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 280)
            Text("🍳 You're cook #\(Format.compactCount(recipe.cook_count + 1)) — this fuels the Trending feed")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                .padding(.horizontal, 16).padding(.vertical, 8).background(Theme.accentSoft, in: Capsule())

            HStack(spacing: 12) {
                VotePillView(recipeId: recipe.id, baseCount: recipe.net_upvotes, size: .lg)
                SaveButtonView(recipeId: recipe.id, variant: .bar)
            }
            .frame(maxWidth: 320)

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
            }

            Button("Back to Discover") { dismiss() }
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, ing in
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
