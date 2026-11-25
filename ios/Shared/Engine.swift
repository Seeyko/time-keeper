import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

enum SaveOutcome: Equatable {
    case immediate
    case delayed(until: Date)
}

enum Shield {
    static func apply(_ group: LimitGroup) {
        let store = ManagedSettingsStore(named: group.storeName)
        let sel = group.selection
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
        store.shield.webDomainCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
    }

    static func clear(_ id: UUID) {
        ManagedSettingsStore(named: LimitGroup.storeName(for: id)).clearAllSettings()
    }
}

enum Engine {
    @discardableResult
    static func save(draft: Rules, now: Date = Date()) -> SaveOutcome {
        var state = SharedStorage.load()
        state = plan(state, draft: draft, now: now)
        SharedStorage.save(state)
        sync(state.active)
        if let date = state.pendingEffective, state.pending != nil { return .delayed(until: date) }
        return .immediate
    }

    static func plan(_ current: TimeKeeperState, draft: Rules, now: Date) -> TimeKeeperState {
        var state = current
        state.active = state.active.isUnrestricted && state.pending == nil ? draft : Rules.strictest(state.active, draft)
        if draft == state.active {
            state.pending = nil
            state.pendingEffective = nil
        } else {
            let keepTimer = state.pending.map { draft.isAtLeastAsStrict(as: $0) } ?? false
            if !keepTimer || state.pendingEffective == nil {
                state.pendingEffective = now.addingTimeInterval(Policy.loosenDelay)
            }
            state.pending = draft
        }
        return state
    }

    static func promote(_ current: TimeKeeperState, now: Date) -> TimeKeeperState {
        var state = current
        if let pending = state.pending, let date = state.pendingEffective, date <= now {
            state.active = pending
            state.pending = nil
            state.pendingEffective = nil
        }
        return state
    }

    static func applyPendingIfDue(now: Date = Date()) {
        let state = promote(SharedStorage.load(), now: now)
        SharedStorage.save(state)
        sync(state.active)
    }

    static func sync(_ rules: Rules) {
        closePassIfDue()
        let center = DeviceActivityCenter()
        if SharedStorage.suspended {
            suspend(center)
            return
        }

        let currentIDs = Set(rules.groups.map(\.id))
        let monitored = Set(rules.groups.filter { !$0.isEmpty }.map(\.activityName))
        for activity in center.activities where LimitGroup.id(from: activity) != nil && !monitored.contains(activity) {
            center.stopMonitoring([activity])
        }
        for id in SharedStorage.knownGroupIDs where !currentIDs.contains(id) {
            Shield.clear(id)
            SharedStorage.forget(id)
        }
        SharedStorage.knownGroupIDs = currentIDs
        if let pass = SharedStorage.activePass, !currentIDs.contains(pass.groupID) {
            PassReminder.cancel()
            closePass()
        }
        let openID = SharedStorage.activePass?.groupID

        let reminders = SharedStorage.reminderSettings
        let schedule = DeviceActivitySchedule(
            intervalStart: rules.dayStart.intervalStart,
            intervalEnd: rules.dayStart.intervalEnd,
            repeats: true
        )
        for group in rules.groups {
            if SharedStorage.isShieldedToday(group.id), group.id != openID { Shield.apply(group) }

            guard !group.isEmpty else {
                SharedStorage.setFingerprint(nil, for: group.id)
                continue
            }
            let fp = fingerprint(group, dayStart: rules.dayStart, reminders: reminders)
            if center.activities.contains(group.activityName), SharedStorage.fingerprint(group.id) == fp {
                continue
            }
            var events = Reminder.events(for: group, settings: reminders)
            events[LimitGroup.eventName] = group.event(after: group.minutes)
            center.stopMonitoring([group.activityName])
            do {
                try center.startMonitoring(group.activityName, during: schedule, events: events)
                SharedStorage.setFingerprint(fp, for: group.id)
            } catch {
                NSLog("TimeKeeper startMonitoring \(group.name): \(error)")
            }
        }

        let domains = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: "domains"))
        let filtered = filteredDomains(rules.blockedDomains)
        domains.webContent.blockedByFilter = filtered.isEmpty ? nil : .specific(filtered)

        let global = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: "global"))
        global.application.denyAppRemoval = rules.denyAppRemoval ? true : nil
    }

    private static func suspend(_ center: DeviceActivityCenter) {
        center.stopMonitoring(center.activities.filter { LimitGroup.id(from: $0) != nil || ActivePass.groupID(from: $0) != nil })
        if SharedStorage.activePass != nil {
            SharedStorage.activePass = nil
            PassReminder.cancel()
        }
        for id in SharedStorage.knownGroupIDs {
            Shield.clear(id)
            SharedStorage.setFingerprint(nil, for: id)
        }
        ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: "domains")).clearAllSettings()
        ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: "global")).clearAllSettings()
    }

    @discardableResult
    static func openPass(for group: LimitGroup, now: Date = Date()) throws -> ActivePass {
        closePassIfDue(now: now)
        let rules = SharedStorage.load().active
        let zone = TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = zone
        guard let ledger = PassStore.load(now: now, timeZone: zone) else { throw PassError.storage }
        let target = rules.groups.first { $0.id == group.id }
        let verdict = Pass.availability(
            ledger,
            now: now,
            timeZone: zone,
            calendar: calendar,
            dayStart: rules.dayStart,
            hasBlockedGroup: target != nil && SharedStorage.isShieldedToday(group.id),
            suspended: SharedStorage.suspended,
            passActive: SharedStorage.activePass
        )
        guard verdict == .available, let target else { throw PassError.refused(verdict) }

        let pass = ActivePass(groupID: target.id, opened: now, until: now.addingTimeInterval(Policy.passDuration))
        let center = DeviceActivityCenter()
        center.stopMonitoring(center.activities.filter { ActivePass.groupID(from: $0) != nil })
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: now),
            intervalEnd: calendar.dateComponents(parts, from: now.addingTimeInterval(Policy.passMonitorWindow)),
            repeats: false,
            warningTime: DateComponents(minute: Int((Policy.passMonitorWindow - Policy.passDuration) / 60))
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if !target.isEmpty {
            events[ActivePass.eventName] = DeviceActivityEvent(
                applications: target.selection.applicationTokens,
                categories: target.selection.categoryTokens,
                webDomains: target.selection.webDomainTokens,
                threshold: DateComponents(minute: Int(Policy.passDuration / 60)),
                includesPastActivity: false
            )
        }
        do {
            try center.startMonitoring(pass.activityName, during: schedule, events: events)
        } catch {
            NSLog("TimeKeeper startMonitoring pass: \(error)")
            throw PassError.monitoring
        }
        let spent = Pass.spend(ledger, now: now, timeZone: zone, calendar: calendar, dayStart: rules.dayStart)
        guard PassStore.save(spent) else {
            center.stopMonitoring([pass.activityName])
            throw PassError.storage
        }
        SharedStorage.activePass = pass
        Shield.clear(target.id)
        return pass
    }

    static func closePassIfDue(now: Date = Date()) {
        guard let pass = SharedStorage.activePass, pass.isOver(at: now) else { return }
        closePass()
    }

    static func closePass(of id: UUID? = nil) {
        if let pass = SharedStorage.activePass, id == nil || id == pass.groupID {
            if !SharedStorage.suspended, SharedStorage.isShieldedToday(pass.groupID),
               let group = SharedStorage.load().active.groups.first(where: { $0.id == pass.groupID }) {
                Shield.apply(group)
            }
            SharedStorage.activePass = nil
        }
        let open = SharedStorage.activePass?.activityName
        let center = DeviceActivityCenter()
        let stale = center.activities.filter { ActivePass.groupID(from: $0) != nil && $0 != open }
        if !stale.isEmpty { center.stopMonitoring(stale) }
    }

    static func filteredDomainNames(_ base: [String]) -> [String] {
        var names = base
        for d in base { names += ["www." + d, "m." + d] }
        var seen = Set<String>()
        return Array(names.filter { seen.insert($0).inserted }.prefix(Policy.maxFilteredDomains))
    }

    static func filteredDomains(_ base: [String]) -> Set<WebDomain> {
        Set(filteredDomainNames(base).map { WebDomain(domain: $0) })
    }

    private static func fingerprint(_ group: LimitGroup, dayStart: DayStart, reminders: ReminderSettings) -> String {
        let data = (try? JSONEncoder().encode(group.selection)) ?? Data()
        return "\(reminders.fingerprint)|\(dayStart.label)|\(group.minutes)|\(data.base64EncodedString())"
    }
}
