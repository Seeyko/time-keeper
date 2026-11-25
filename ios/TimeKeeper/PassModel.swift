import SwiftUI

@MainActor
final class PassModel: ObservableObject {
    let demo: Bool
    @Published private(set) var ledger: PassLedger
    @Published private(set) var active: ActivePass?
    @Published private(set) var reminder: PassReminder

    let shift: TimeInterval
    private var closing: Task<Void, Never>?

    init(demo: Bool) {
        self.demo = demo
        let now = Date()
        shift = demo ? (Calendar.current.date(bySettingHour: 12, minute: 42, second: 0, of: now) ?? now).timeIntervalSince(now) : 0
        if demo {
            ledger = PassLedger(now: now.addingTimeInterval(-24 * 60 * 60), timeZone: .current)
            active = nil
            reminder = .minuteBefore
        } else {
            ledger = PassStore.load(now: now) ?? PassLedger(now: now, timeZone: .current, stock: 0)
            active = SharedStorage.activePass
            reminder = SharedStorage.passReminder
        }
    }

    var stock: Int { ledger.stock }

    var now: Date { Date().addingTimeInterval(shift) }

    func isOpen(_ id: UUID, now: Date? = nil) -> Bool {
        let now = now ?? self.now
        guard let active, active.groupID == id else { return false }
        return !active.isOver(at: now)
    }

    func refresh(now: Date? = nil) {
        let now = now ?? self.now
        if demo {
            if let active, active.isOver(at: now) { self.active = nil }
            watch()
            return
        }
        NSTimeZone.resetSystemTimeZone()
        Engine.closePassIfDue(now: now)
        active = SharedStorage.activePass
        if let stored = PassStore.load(now: now) {
            let current = Pass.refreshed(stored, now: now, timeZone: .current)
            if current != stored { PassStore.save(current) }
            ledger = current
        }
        watch()
    }

    func availability(blocked: Bool, dayStart: DayStart, now: Date? = nil) -> PassAvailability {
        let now = now ?? self.now
        let verdict = evaluate(blocked: blocked, dayStart: dayStart, now: now)
        guard demo, verdict == .night else { return verdict }
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        return evaluate(blocked: blocked, dayStart: dayStart, now: noon)
    }

    @discardableResult
    func open(_ group: LimitGroup, blocked: Bool, dayStart: DayStart, now: Date? = nil) throws -> ActivePass {
        let now = now ?? self.now
        guard demo else {
            let pass = try Engine.openPass(for: group, now: now)
            refresh(now: now)
            reminder.schedule(for: group, until: pass.until, now: now)
            return pass
        }
        let verdict = availability(blocked: blocked, dayStart: dayStart, now: now)
        guard verdict == .available else { throw PassError.refused(verdict) }
        let pass = ActivePass(groupID: group.id, opened: now, until: now.addingTimeInterval(Policy.passDuration))
        ledger = Pass.spend(ledger, now: now, timeZone: .current, calendar: .current, dayStart: dayStart)
        active = pass
        watch()
        return pass
    }

    func setReminder(_ value: PassReminder) {
        reminder = value
        if demo { return }
        SharedStorage.passReminder = value
        PassReminder.cancel()
        guard let active, !active.isOver(at: now),
              let group = SharedStorage.load().active.groups.first(where: { $0.id == active.groupID }) else { return }
        value.schedule(for: group, until: active.until)
    }

    private func evaluate(blocked: Bool, dayStart: DayStart, now: Date) -> PassAvailability {
        Pass.availability(
            ledger,
            now: now,
            timeZone: .current,
            calendar: .current,
            dayStart: dayStart,
            hasBlockedGroup: blocked,
            suspended: !demo && SharedStorage.suspended,
            passActive: active
        )
    }

    private func watch() {
        closing?.cancel()
        guard let until = active?.until else { return }
        let delay = max(0, until.timeIntervalSince(now)) + 1
        closing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
