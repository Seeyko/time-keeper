import SwiftUI

struct PassSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var pass: PassModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var chosen: UUID?
    @State private var airlockEnd: Date?
    @State private var frozenAt: Date?
    @State private var anchor = Date()
    @State private var opening = false
    @State private var flip: CGFloat = 1
    @State private var failed = false
    @State private var opened = 0
    @State private var cancelled = 0

    private var motion: Animation { reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4) }

    private var blocked: [LimitGroup] {
        model.active.groups.filter { model.isBlockedToday($0.id) && !pass.isOpen($0.id) }
    }

    private var target: LimitGroup? {
        blocked.first(where: { $0.id == chosen }) ?? blocked.first
    }

    private var openName: String {
        model.active.groups.first(where: { $0.id == pass.active?.groupID })?.name ?? ""
    }

    var body: some View {
        TimelineView(.periodic(from: (airlockEnd ?? anchor).addingTimeInterval(-Policy.passAirlock), by: 1)) { context in
            tick(frozenAt ?? context.date)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if airlockEnd == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(airlockEnd != nil)
        .sensoryFeedback(.selection, trigger: chosen)
        .sensoryFeedback(.selection, trigger: pass.reminder)
        .sensoryFeedback(.selection, trigger: cancelled)
        .sensoryFeedback(.impact(weight: .medium), trigger: airlockEnd) { _, end in end != nil }
        .sensoryFeedback(.success, trigger: opened)
        .sensoryFeedback(.error, trigger: failed) { _, now in now }
        .onAppear(perform: stageCapture)
    }

    private func secondsLeft(_ now: Date) -> Int? {
        guard let airlockEnd else { return nil }
        let remaining = Int(airlockEnd.timeIntervalSince(now).rounded())
        return min(Int(Policy.passAirlock), max(0, remaining))
    }

    private func tick(_ now: Date) -> some View {
        let verdict = pass.availability(blocked: !blocked.isEmpty, dayStart: model.active.dayStart, now: now)
        let left = secondsLeft(now)
        return content(verdict: verdict, left: left, now: now)
            .onChange(of: left) { (_: Int?, seconds: Int?) in
                if seconds == 0 { finish() }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: left) { (_: Int?, seconds: Int?) -> Bool in
                seconds.map { [20, 10].contains($0) } ?? false
            }
    }

    private func content(verdict: PassAvailability, left: Int?, now: Date) -> some View {
        let until = openUntil(verdict)
        let choosing = left == nil && until == nil
        let tokenFace = face(verdict: verdict, now: now)
        return List {
            Section {
                VStack(spacing: 8) {
                    PassToken(face: tokenFace, stock: pass.stock, size: choosing ? 168 : 208)
                        .animation(reduceMotion ? nil : .linear(duration: 1), value: tokenFace)
                        .scaleEffect(x: flip, y: 1)
                        .padding(.top, choosing ? 8 : 48)
                        .padding(.bottom, 16)
                    Text(title(left: left, until: until))
                        .font(.title.bold())
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                    Text(line(verdict: verdict, choosing: choosing, left: left))
                        .foregroundStyle(choosing && failed ? Theme.blocked : Color.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if choosing && verdict == .available {
                Section {
                    ForEach(blocked) { group in
                        row(group)
                    }
                }
                Section {
                    Picker("Me prévenir", selection: Binding(
                        get: { pass.reminder },
                        set: { pass.setReminder($0) }
                    )) {
                        ForEach(PassReminder.allCases, id: \.self) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            action(verdict: verdict, airlock: left != nil, open: until != nil)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    @ViewBuilder
    private func action(verdict: PassAvailability, airlock: Bool, open: Bool) -> some View {
        if airlock {
            Button(action: cancel) {
                Text("Annuler")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        } else if open {
            Button {
                dismiss()
            } label: {
                Text("OK").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            Button(action: start) {
                Text("Ouvrir 5 min").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(verdict != .available || target == nil)
        }
    }

    private func row(_ group: LimitGroup) -> some View {
        let selected = target?.id == group.id
        return Button {
            chosen = group.id
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name.isEmpty ? "Sans nom" : group.name)
                        Text("\(formatMinutes(group.minutes)) par jour")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Tile(glyph: .lock, tint: .red)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func openUntil(_ verdict: PassAvailability) -> Date? {
        if case .open(let until) = verdict { return until }
        return nil
    }

    private func face(verdict: PassAvailability, now: Date) -> PassToken.Face {
        if let airlockEnd {
            return .airlock(min(1, max(0, 1 - airlockEnd.timeIntervalSince(now) / Policy.passAirlock)))
        }
        switch verdict {
        case .open(let until): return .open(min(1, max(0, until.timeIntervalSince(now) / Policy.passDuration)))
        case .empty: return .spent
        default: return .rest
        }
    }

    private func title(left: Int?, until: Date?) -> String {
        if let left { return "Ça s'ouvre dans \(left) s" }
        if let until { return "Ouvert jusqu'à \(until.passTime)" }
        return "Ouvrir une parenthèse"
    }

    private func line(verdict: PassAvailability, choosing: Bool, left: Int?) -> String {
        if left != nil { return target?.name ?? "" }
        if !choosing { return openName }
        if failed { return "Pas ouvert. Réessaie dans un moment." }
        switch verdict {
        case .night: return "Pas entre 22 h et 6 h."
        case .usedToday: return "Déjà utilisée aujourd'hui."
        case .nothingBlocked, .suspended: return "Rien n'est bloqué."
        case .empty(let next): return "Prochaine le \(next.passDay)"
        case .clockMoved: return "Remets l'heure automatique."
        case .available, .open: return "5 min sur une limite. Elle se referme seule."
        }
    }

    private func start() {
        guard target != nil else { return }
        failed = false
        withAnimation(motion) { airlockEnd = Date().addingTimeInterval(Policy.passAirlock) }
    }

    private func cancel() {
        guard !opening else { return }
        cancelled += 1
        frozenAt = nil
        withAnimation(motion) { airlockEnd = nil }
    }

    private func finish() {
        guard !opening, let end = airlockEnd else { return }
        guard let id = target?.id, Date().timeIntervalSince(end) < Policy.passDuration else {
            airlockEnd = nil
            return
        }
        opening = true
        if reduceMotion {
            withAnimation(motion) { commit(id) }
            return
        }
        withAnimation(.easeIn(duration: 0.35)) {
            flip = 0.02
        } completion: {
            commit(id)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { flip = 1 }
        }
    }

    private func commit(_ id: UUID) {
        if let group = model.active.groups.first(where: { $0.id == id }) {
            do {
                try pass.open(group, blocked: true, dayStart: model.active.dayStart)
                opened += 1
            } catch PassError.refused(_) {
                failed = false
            } catch {
                failed = true
            }
        }
        airlockEnd = nil
        opening = false
    }

    private func stageCapture() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-pass-film"), airlockEnd == nil {
            chosen = blocked.first?.id
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(motion) { airlockEnd = Date().addingTimeInterval(6) }
            }
            return
        }
        guard arguments.contains("-pass-sas"), airlockEnd == nil else { return }
        let start = Date()
        chosen = blocked.first?.id
        frozenAt = start
        airlockEnd = start.addingTimeInterval(18)
    }
}

extension PassReminder {
    var label: String {
        switch self {
        case .minuteBefore: "1 min avant"
        case .atEnd: "À la fin"
        case .never: "Jamais"
        }
    }
}

extension Date {
    private static let french = Locale(identifier: "fr_FR")

    var passTime: String { formatted(.dateTime.hour().minute().locale(Date.french)) }
    var passDay: String { formatted(.dateTime.day().month(.abbreviated).locale(Date.french)) }
}
