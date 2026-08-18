import WidgetKit
import SwiftUI
import ActivityKit

@main
struct AdaptableWidgets: WidgetBundle {
    var body: some Widget {
        TonightWidget()
        CookLiveActivityWidget()
    }
}

struct TonightEntry: TimelineEntry {
    let date: Date
    let recipeId: String?
    let title: String
    let emoji: String
    let planDate: String
}

struct TonightProvider: TimelineProvider {
    func placeholder(in context: Context) -> TonightEntry {
        TonightEntry(date: Date(), recipeId: nil, title: "Tonight's meal", emoji: "🍽️", planDate: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (TonightEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func current() -> TonightEntry {
        let defaults = UserDefaults(suiteName: "group.com.adaptable.app")
        let id = defaults?.string(forKey: "tonight.recipeId")
        return TonightEntry(
            date: Date(),
            recipeId: id,
            title: defaults?.string(forKey: "tonight.title") ?? "Nothing planned",
            emoji: defaults?.string(forKey: "tonight.emoji") ?? "🍽️",
            planDate: defaults?.string(forKey: "tonight.date") ?? ""
        )
    }
}

struct TonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AdaptableTonight", provider: TonightProvider()) { entry in
            TonightView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tonight")
        .description("Tonight's planned meal — tap to start Cook Mode.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TonightView: View {
    let entry: TonightEntry

    var body: some View {
        let url = entry.recipeId.flatMap { URL(string: "com.adaptable.app://cook?id=\($0)") }
        VStack(alignment: .leading, spacing: 8) {
            Text("TONIGHT").font(.system(size: 10, weight: .heavy)).foregroundStyle(.orange)
            Text(entry.emoji).font(.system(size: 32))
            Text(entry.title).font(.system(size: 15, weight: .heavy)).lineLimit(2)
            if !entry.planDate.isEmpty {
                Text(entry.planDate).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(url)
    }
}

struct CookLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookActivityAttributes.self) { context in
            HStack {
                Text(context.attributes.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.recipeTitle).font(.headline)
                    Text(context.state.stepLabel).font(.subheadline)
                }
                Spacer()
                if let end = context.state.timerEndsAt {
                    Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
                        .monospacedDigit()
                        .font(.headline)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.7))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.emoji)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.stepLabel).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = context.state.timerEndsAt {
                        Text(timerInterval: Date.now...max(Date.now, end), countsDown: true).monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Link(destination: URL(string: "com.adaptable.app://cook/next")!) {
                            Text("Next step").font(.system(size: 13, weight: .bold))
                        }
                        Link(destination: URL(string: "com.adaptable.app://cook/timer")!) {
                            Text("Start timer").font(.system(size: 13, weight: .bold))
                        }
                    }
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                if let end = context.state.timerEndsAt {
                    Text(timerInterval: Date.now...max(Date.now, end), countsDown: true).monospacedDigit().font(.caption2)
                } else {
                    Text(context.state.stepLabel).font(.caption2)
                }
            } minimal: {
                Text(context.attributes.emoji)
            }
        }
    }
}
