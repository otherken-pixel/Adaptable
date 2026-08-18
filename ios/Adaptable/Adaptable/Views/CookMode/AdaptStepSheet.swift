import SwiftUI

struct AdaptStepSheet: View {
    let recipeTitle: String
    let ingredients: [StepIngredientUse]
    let substitutions: [String: String]
    var onApply: (String, String) -> Void
    var onAskAI: (String) -> Void
    var onDismiss: () -> Void

    @State private var selectedItem: String?
    @State private var custom = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Swap just this step so you can keep cooking. Bigger changes can go to Remix.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)

                    if ingredients.isEmpty {
                        Text("This step doesn’t list specific ingredients — describe what you’re out of below.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }

                    ForEach(ingredients) { ing in
                        ingredientCard(ing)
                    }

                    customBlock
                }
                .padding(20)
            }
            .background(Theme.surface)
            .navigationTitle("I’m out of something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func ingredientCard(_ ing: StepIngredientUse) -> some View {
        let original = originalName(ing)
        let current = substitutions[original] ?? ing.item
        let expanded = selectedItem == original
        let swaps = Substitutions.suggestions(for: original)

        VStack(alignment: .leading, spacing: 10) {
            Button {
                selectedItem = expanded ? nil : original
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.content)
                        HStack(spacing: 6) {
                            Text(ing.quantity)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.muted)
                            if current != original {
                                Text("was \(original)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adapt \(current)")

            if expanded {
                ForEach(swaps) { swap in
                    Button {
                        onApply(original, swap.name)
                        selectedItem = nil
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(swap.name).font(.subheadline.weight(.bold)).foregroundStyle(Theme.content)
                                Text(swap.note).font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Swap \(original) for \(swap.name)")
                }

                Button {
                    onApply(original, "omit")
                    selectedItem = nil
                } label: {
                    Label("Cook without it", systemImage: "minus.circle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
    }

    private var customBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Something else")
                .font(.subheadline.weight(.heavy))
            TextField("I’m out of…", text: $custom, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Button {
                let text = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                if let item = selectedItem {
                    onApply(item, text)
                } else {
                    onAskAI(text)
                }
            } label: {
                Text("Apply this swap")
                    .font(.body.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .foregroundStyle(.white)
                    .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (selectedItem == nil && !ingredients.isEmpty))

            Button {
                let text = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                let prompt: String
                if text.isEmpty, let item = selectedItem {
                    prompt = "I'm cooking \(recipeTitle) and I'm out of \(item) on this step. Adapt the recipe."
                } else if text.isEmpty {
                    prompt = "I'm cooking \(recipeTitle) and I need to adapt this step — I'm out of an ingredient."
                } else {
                    prompt = "I'm cooking \(recipeTitle). \(text)"
                }
                onAskAI(prompt)
            } label: {
                Label("Ask AI to remix the whole recipe", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .foregroundStyle(Theme.accent)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
        .padding(14)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
    }

    private func originalName(_ ing: StepIngredientUse) -> String {
        substitutions.first(where: { $0.value == ing.item })?.key ?? ing.item
    }
}
