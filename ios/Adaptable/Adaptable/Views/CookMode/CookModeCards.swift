import SwiftUI

/// Shared Cook Mode cards: context chips, action list, this-step ingredients,
/// timers, doneness, meanwhile, and the iPad inspector.

struct CookContextBar: View {
    let servings: Int
    let totalMinutes: Int
    let temperature: String?
    let equipment: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(systemImage: "person.2", text: "\(servings) servings")
                if totalMinutes > 0 {
                    chip(systemImage: "clock", text: "\(totalMinutes)m total")
                }
                if let temperature, !temperature.isEmpty {
                    chip(systemImage: "thermometer", text: temperature)
                }
                ForEach(equipment, id: \.self) { item in
                    chip(systemImage: "fork.knife", text: item)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func chip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.accentSoft, in: Capsule())
            .fixedSize()
    }
}

struct CookActionList: View {
    let actions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(actions.enumerated()), id: \.offset) { i, action in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.surface)
                        .frame(width: 28, height: 28)
                        .background(Theme.content, in: Circle())
                        .padding(.top, 2)
                    Text(action)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.content)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 720, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Action \(i + 1): \(action)")
            }
        }
    }
}

struct CookStepIngredientList: View {
    let ingredients: [StepIngredientUse]
    let gathered: Set<Int>
    var onToggle: (StepIngredientUse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS STEP USES")
                .font(.caption.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(Theme.accent)

            VStack(spacing: 0) {
                ForEach(Array(ingredients.enumerated()), id: \.element.id) { i, ing in
                    if i > 0 { Divider().overlay(Theme.line) }
                    Button { onToggle(ing) } label: {
                        HStack(spacing: 12) {
                            let done = isDone(ing)
                            Circle()
                                .strokeBorder(done ? Theme.accent : Theme.line, lineWidth: 2)
                                .background(Circle().fill(done ? Theme.accent : .clear))
                                .frame(width: 24, height: 24)
                                .overlay(done ? Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.white) : nil)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.item)
                                    .font(.body.weight(.semibold))
                                    .strikethrough(done)
                                    .foregroundStyle(Theme.content)
                                HStack(spacing: 6) {
                                    if let note = ing.note, !note.isEmpty {
                                        Text(note).font(.caption).foregroundStyle(Theme.faint)
                                    }
                                    if ing.source == .pantry {
                                        Text("pantry").font(.caption2.weight(.bold)).foregroundStyle(Theme.accent)
                                    }
                                    if ing.source == .yield {
                                        Text("from this recipe").font(.caption2.weight(.bold)).foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            Text(ing.quantity)
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.trailing)
                        }
                        .opacity(isDone(ing) ? 0.45 : 1)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(ing.item), \(ing.quantity)\(ing.note.map { ", \($0)" } ?? "")")
                    .accessibilityAddTraits(isDone(ing) ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        }
    }

    private func isDone(_ ing: StepIngredientUse) -> Bool {
        if let idx = ing.recipeIndex { return gathered.contains(idx) }
        return false
    }
}

struct CookTimerCard: View {
    let spec: ExtractedTimer
    let remaining: Int
    let running: Bool
    let finished: Bool
    var onStart: () -> Void
    var onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(finished ? Theme.accent : Theme.accentSoft)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: spec.systemImage)
                        .foregroundStyle(finished ? .white : Theme.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(DurationParser.formatClock(remaining))
                    .font(.title2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.content)
                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(finished ? Theme.accent : Theme.faint)
            }
            Spacer()
            if !running {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Theme.heroGradient, in: Circle())
                }
                .accessibilityLabel("Start \(spec.label) timer")
            } else {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(Theme.muted)
                        .frame(width: 48, height: 48)
                        .background(Theme.raised, in: Circle())
                        .overlay(Circle().stroke(Theme.line))
                }
                .accessibilityLabel("Reset \(spec.label) timer")
            }
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(finished ? Theme.accent : Theme.line))
    }

    private var caption: String {
        if finished { return "\(spec.label) — time’s up" }
        if running { return "\(spec.label) — keeps going between steps" }
        if spec.kind == .preheat { return "\(spec.label) · typical time to temperature" }
        return spec.label
    }
}

struct CookCueCard: View {
    let systemImage: String
    let title: String
    let bodyText: String
    var accented: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(accented ? Theme.accent : Theme.muted)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(accented ? Theme.accent : Theme.muted)
                Text(bodyText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(accented ? Theme.accent : Theme.content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (accented ? Theme.accentSoft : Theme.raised),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accented ? Color.clear : Theme.line)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(bodyText)")
    }
}
