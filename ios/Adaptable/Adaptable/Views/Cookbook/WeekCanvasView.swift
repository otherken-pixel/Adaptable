import SwiftUI

/// Next-7-days canvas. Tap a meal to move it; tap an empty day to park a pending bundle.
struct WeekCanvasView: View {
    let plans: [MealPlanEntry]
    var onMove: (MealPlanEntry, String) -> Void
    var onSelectDay: (String) -> Void

    @State private var moving: MealPlanEntry?

    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("THIS WEEK").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.accent)
                Spacer()
                if moving != nil {
                    Button("Cancel") { moving = nil }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        dayColumn(date)
                    }
                }
            }
        }
    }

    private func dayColumn(_ date: Date) -> some View {
        let iso = Format.localISODate(date)
        let meals = plans.filter { $0.plan_date == iso }
        let today = Format.localISODate()
        return Button {
            if let moving {
                onMove(moving, iso)
                self.moving = nil
            } else {
                onSelectDay(iso)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(shortDay(date))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(iso == today ? Theme.accent : Theme.muted)
                Text(String(iso.suffix(2)))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.content)
                if meals.isEmpty {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(moving != nil ? Theme.accent : Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(height: 36)
                        .overlay(
                            Text(moving != nil ? "Drop" : "—")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.faint)
                        )
                } else {
                    ForEach(meals) { entry in
                        Text("\(entry.recipe?.emoji ?? "🍽️") \(entry.recipe?.title ?? "Meal")")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(2)
                            .foregroundStyle(Theme.content)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(entry.leftover_of == nil ? Theme.sunken : Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onLongPressGesture {
                                moving = entry
                                Haptics.selection()
                            }
                    }
                }
            }
            .padding(8)
            .frame(width: 108, alignment: .topLeading)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(iso == today ? Theme.accent.opacity(0.4) : Theme.line))
        }
        .buttonStyle(.plain)
    }

    private func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
}
