import SwiftUI

/// Multi-step first-run taste capture. Mirrors `src/pages/OnboardingPage.tsx`.
struct OnboardingView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var deepLinks: DeepLinkCenter
    var onFinished: () -> Void

    @State private var step = 0
    @State private var busy = false
    @State private var diets: Set<String> = []
    @State private var allergies: Set<String> = []
    @State private var household = 2
    @State private var spice = "Medium"
    @State private var skill = "Confident"

    private let dietOptions = [
        "Vegetarian", "Vegan", "Pescatarian", "Keto", "Paleo",
        "Gluten-free", "Dairy-free", "Halal", "Kosher",
    ]
    private let allergyOptions = [
        "Peanuts", "Tree nuts", "Dairy", "Eggs", "Gluten",
        "Shellfish", "Fish", "Soy", "Sesame",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progress
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch step {
                    case 0: welcome
                    case 1: dietStep
                    case 2: allergyStep
                    case 3: householdStep
                    default: done
                    }
                }
                .padding(20)
            }
            footer
        }
        .background(Theme.surface.ignoresSafeArea())
        .onAppear {
            if let p = authStore.profile?.preferences {
                diets = Set(p.diets ?? [])
                allergies = Set(p.allergies ?? [])
                household = p.household_size ?? 2
                spice = p.spice ?? "Medium"
                skill = p.skill ?? "Confident"
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.sunken)
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(step + 1) / 5)
                }
            }
            .frame(height: 6)
            Text("STEP \(step + 1) OF 5")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.faint)
                .tracking(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Onboarding step \(step + 1) of 5")
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🍳").font(.system(size: 48))
            Text("Welcome\(authStore.profile?.username.map { ", \($0)" } ?? "")")
                .font(.system(size: 28, weight: .heavy))
            Text("In under a minute we’ll learn how you eat — especially allergies, which we treat as a hard safety rule on every AI recipe.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.fill").foregroundStyle(Theme.accent)
                Text("Always double-check ingredients for severe allergies. We block obvious mismatches, but you’re the final safety check.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(14)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var dietStep: some View {
        chipStep(title: "Any diets?", subtitle: "Pick all that apply — or skip if you’re flexible.", options: dietOptions, selected: $diets)
    }

    private var allergyStep: some View {
        chipStep(title: "Allergies & hard avoids", subtitle: "We never want these in a generated or imported recipe.", options: allergyOptions, selected: $allergies, danger: true)
    }

    private func chipStep(title: String, subtitle: String, options: [String], selected: Binding<Set<String>>, danger: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 26, weight: .heavy))
            Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.muted)
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    let on = selected.wrappedValue.contains(opt)
                    Button {
                        Haptics.selection()
                        if on { selected.wrappedValue.remove(opt) } else { selected.wrappedValue.insert(opt) }
                    } label: {
                        Text(opt)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .foregroundStyle(on ? (danger ? Theme.down : Theme.surface) : Theme.muted)
                            .background(
                                on
                                    ? AnyShapeStyle(danger ? Theme.down.opacity(0.15) : Theme.content)
                                    : AnyShapeStyle(Theme.raised),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(on && danger ? Theme.down.opacity(0.4) : Theme.line))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var householdStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Household & vibe").font(.system(size: 26, weight: .heavy))
            Text("PEOPLE YOU COOK FOR")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.faint).tracking(1)
            HStack(spacing: 16) {
                stepButton("−") { household = max(1, household - 1) }
                Text("\(household)").font(.system(size: 28, weight: .heavy)).monospacedDigit().frame(minWidth: 36)
                stepButton("+") { household = min(12, household + 1) }
            }
            Text("SPICE").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.faint).tracking(1)
            chipRow(["Mild", "Medium", "Hot"], selected: spice) { spice = $0 }
            Text("SKILL").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.faint).tracking(1)
            chipRow(["Beginner", "Confident", "Pro"], selected: skill) { skill = $0 }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✨").font(.system(size: 48))
            Text("You’re set").font(.system(size: 26, weight: .heavy))
            Text("We’ll adapt every AI recipe to your tastes and keep allergens out.")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
            Label("Ready to generate your first dinner", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task { await advance() }
            } label: {
                HStack {
                    if busy { ProgressView().tint(Theme.surface) }
                    Text(step >= 4 ? "Generate a recipe" : "Continue")
                        .font(.system(size: 16, weight: .heavy))
                }
                .frame(maxWidth: .infinity).frame(height: 54)
                .foregroundStyle(.white)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(busy)
            .accessibilityLabel(step >= 4 ? "Generate a recipe" : "Continue onboarding")

            if step == 0 {
                Button("Skip onboarding") { finish(save: false) }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
            } else if step < 4 {
                Button("Skip for now") { step += 1; Haptics.selection() }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(20)
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title).font(.system(size: 20, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Theme.raised, in: Circle())
                .overlay(Circle().stroke(Theme.line))
        }
        .buttonStyle(.pressable)
    }

    private func chipRow(_ options: [String], selected: String, onPick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                Button {
                    Haptics.selection()
                    onPick(opt)
                } label: {
                    Text(opt).font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .foregroundStyle(selected == opt ? Theme.surface : Theme.muted)
                        .background(selected == opt ? Theme.content : Theme.raised, in: Capsule())
                        .overlay(Capsule().stroke(selected == opt ? .clear : Theme.line))
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func advance() async {
        if step < 4 {
            Haptics.light()
            step += 1
            return
        }
        await finish(save: true)
    }

    private func finish(save: Bool) {
        Task {
            busy = true
            if save {
                var prefs = authStore.profile?.preferences ?? .empty
                prefs.diets = Array(diets)
                prefs.allergies = Array(allergies)
                prefs.household_size = household
                prefs.spice = spice
                prefs.skill = skill
                try? await authStore.updatePreferences(prefs)
            }
            UserDefaults.standard.set(true, forKey: "adaptable.onboarding.v1.done")
            UserDefaults.standard.set(true, forKey: "adaptable.tasteNudge.v1.dismissed")
            Haptics.success()
            busy = false
            deepLinks.activeTab = .create
            onFinished()
        }
    }
}
