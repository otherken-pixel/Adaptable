import SwiftUI

struct HouseholdCard: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var house: Household?
    @State private var members: [HouseholdMember] = []
    @State private var codeDraft = ""
    @State private var nameDraft = "Our kitchen"
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOUSEHOLD").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(Theme.accent)
            Text("Share the plan and grocery list with whoever you cook with.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted)

            if let house {
                VStack(alignment: .leading, spacing: 8) {
                    Text(house.name).font(.system(size: 16, weight: .heavy))
                    Text("Invite code \(house.invite_code)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    ForEach(members, id: \.user_id) { m in
                        Text("\(m.username ?? "chef") · \(m.role)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    Button("Leave kitchen") {
                        Task { await leave() }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.down)
                }
            } else {
                TextField("Kitchen name", text: $nameDraft)
                    .padding(10)
                    .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    Task { await create() }
                } label: {
                    Text(busy ? "Creating…" : "Start a shared kitchen")
                        .font(.system(size: 14, weight: .heavy))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .foregroundStyle(Theme.surface)
                        .background(Theme.content, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(busy)

                HStack {
                    TextField("Invite code", text: $codeDraft)
                        .textInputAutocapitalization(.characters)
                        .padding(10)
                        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Join") { Task { await join() } }
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                        .disabled(busy || codeDraft.count < 4)
                }
            }

            if let error {
                Text(error).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.down)
            }
        }
        .padding(16)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line))
        .task { await reload() }
    }

    private func reload() async {
        do {
            if let pair = try await API.fetchHousehold() {
                house = pair.0
                members = pair.1
            } else {
                house = nil
                members = []
            }
        } catch {
            self.error = AppError.friendlyMessage(for: error)
        }
    }

    private func create() async {
        busy = true
        error = nil
        do {
            house = try await API.createHousehold(name: nameDraft)
            await reload()
            Haptics.success()
        } catch {
            self.error = AppError.friendlyMessage(for: error)
        }
        busy = false
    }

    private func join() async {
        busy = true
        error = nil
        do {
            house = try await API.joinHousehold(code: codeDraft)
            await reload()
            Haptics.success()
        } catch {
            self.error = AppError.friendlyMessage(for: error)
        }
        busy = false
    }

    private func leave() async {
        guard let userId = authStore.profile?.id else { return }
        do {
            try await API.leaveHousehold(userId: userId)
            house = nil
            members = []
        } catch {
            self.error = AppError.friendlyMessage(for: error)
        }
    }
}
