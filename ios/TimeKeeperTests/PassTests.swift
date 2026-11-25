import XCTest
@testable import TimeKeeper

final class PassTests: XCTestCase {
    private let paris = TimeZone(identifier: "Europe/Paris")!
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let fourAM = DayStart(hour: 4, minute: 0)
    private let day: TimeInterval = 24 * 60 * 60

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        return calendar
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    private func ledger(stock: Int, at date: Date) -> PassLedger {
        PassLedger(now: date, timeZone: paris, stock: stock)
    }

    private func verdict(
        _ ledger: PassLedger,
        _ now: Date,
        zone: TimeZone? = nil,
        dayStart: DayStart? = nil,
        blocked: Bool = true,
        suspended: Bool = false,
        active: ActivePass? = nil
    ) -> PassAvailability {
        Pass.availability(
            ledger,
            now: now,
            timeZone: zone ?? paris,
            calendar: calendar,
            dayStart: dayStart ?? fourAM,
            hasBlockedGroup: blocked,
            suspended: suspended,
            passActive: active
        )
    }

    private func spend(_ ledger: PassLedger, _ now: Date, dayStart: DayStart? = nil) -> PassLedger {
        Pass.spend(ledger, now: now, timeZone: paris, calendar: calendar, dayStart: dayStart ?? fourAM)
    }

    func testNewLedgerStartsWithOne() {
        let fresh = PassLedger(now: at(2, 12), timeZone: paris)
        XCTAssertEqual(fresh.stock, 1)
        XCTAssertEqual(Policy.passInitialStock, 1)
        XCTAssertEqual(verdict(fresh, at(2, 12)), .available)
    }

    func testRefillsOneEveryFourteenDays() {
        let start = at(2, 12)
        let empty = ledger(stock: 0, at: start)
        XCTAssertEqual(Pass.refreshed(empty, now: start.addingTimeInterval(Policy.passRefill - 1), timeZone: paris).stock, 0)
        let once = Pass.refreshed(empty, now: start.addingTimeInterval(Policy.passRefill), timeZone: paris)
        XCTAssertEqual(once.stock, 1)
        XCTAssertEqual(once.refillAnchor, start.addingTimeInterval(Policy.passRefill))
        XCTAssertEqual(Pass.refreshed(once, now: start.addingTimeInterval(20 * day), timeZone: paris).stock, 1)
        XCTAssertEqual(Pass.refreshed(once, now: start.addingTimeInterval(28 * day), timeZone: paris).stock, 2)
        XCTAssertEqual(verdict(empty, start.addingTimeInterval(day)), .empty(next: start.addingTimeInterval(Policy.passRefill)))
    }

    func testStockIsCappedAtTwo() {
        let start = at(2, 12)
        let later = start.addingTimeInterval(100 * day)
        let out = Pass.refreshed(ledger(stock: 0, at: start), now: later, timeZone: paris)
        XCTAssertEqual(out.stock, Policy.passMaxStock)
        XCTAssertEqual(out.stock, 2)
        XCTAssertEqual(out.refillAnchor, later)
    }

    func testFullStockDoesNotBankTime() {
        let start = at(2, 12)
        let later = start.addingTimeInterval(30 * day)
        let full = Pass.refreshed(ledger(stock: 2, at: start), now: later, timeZone: paris)
        XCTAssertEqual(full.refillAnchor, later)
        let spent = spend(full, later)
        XCTAssertEqual(spent.stock, 1)
        XCTAssertEqual(spent.refillAnchor, later)
        XCTAssertEqual(Pass.refreshed(spent, now: later.addingTimeInterval(13 * day), timeZone: paris).stock, 1)
        XCTAssertEqual(Pass.refreshed(spent, now: later.addingTimeInterval(14 * day), timeZone: paris).stock, 2)
    }

    func testSpendingBelowFullKeepsTheAnchor() {
        let start = at(2, 12)
        let one = ledger(stock: 1, at: start)
        let spent = spend(one, start.addingTimeInterval(3 * day))
        XCTAssertEqual(spent.stock, 0)
        XCTAssertEqual(spent.refillAnchor, start)
        XCTAssertEqual(spent.lastUsedDay, "2026-11-05")
        XCTAssertEqual(spend(spent, start.addingTimeInterval(4 * day)).stock, 0)
    }

    func testOncePerDayFollowsDayStart() {
        let used = spend(ledger(stock: 2, at: at(2, 12)), at(2, 21))
        XCTAssertEqual(used.lastUsedDay, "2026-11-02")
        XCTAssertEqual(verdict(used, at(2, 21, 30)), .usedToday)
        XCTAssertEqual(verdict(used, at(3, 3, 59)), .usedToday)
        XCTAssertEqual(verdict(used, at(3, 5)), .night)
        XCTAssertEqual(verdict(used, at(3, 6)), .available)

        let early = spend(ledger(stock: 2, at: at(2, 12)), at(3, 6), dayStart: DayStart())
        XCTAssertEqual(early.lastUsedDay, "2026-11-03")
        XCTAssertEqual(verdict(early, at(3, 21, 59), dayStart: DayStart()), .usedToday)
        XCTAssertEqual(verdict(early, at(4, 6), dayStart: DayStart()), .available)
    }

    func testNightBounds() {
        let one = ledger(stock: 1, at: at(2, 12))
        XCTAssertEqual(verdict(one, at(2, 21, 59, 59)), .available)
        XCTAssertEqual(verdict(one, at(2, 22)), .night)
        XCTAssertEqual(verdict(one, at(3, 0)), .night)
        XCTAssertEqual(verdict(one, at(3, 5, 59, 59)), .night)
        XCTAssertEqual(verdict(one, at(3, 6)), .available)
    }

    func testClockMovedBack() {
        let seen = at(2, 18)
        let one = ledger(stock: 1, at: seen)
        XCTAssertEqual(verdict(one, seen.addingTimeInterval(-60)), .available)
        XCTAssertEqual(verdict(one, seen.addingTimeInterval(-Policy.passClockTolerance)), .available)
        XCTAssertEqual(verdict(one, seen.addingTimeInterval(-Policy.passClockTolerance - 1)), .clockMoved)
        XCTAssertEqual(verdict(one, at(2, 12)), .clockMoved)
        XCTAssertEqual(Pass.refreshed(one, now: at(2, 12), timeZone: paris), one)

        let empty = ledger(stock: 0, at: seen)
        let cheated = Pass.refreshed(empty, now: seen.addingTimeInterval(-day), timeZone: paris)
        XCTAssertEqual(cheated, empty)
    }

    func testClockMovedForwardThenFreezes() {
        let start = at(2, 12)
        let jump = start.addingTimeInterval(Policy.passRefill)
        let ahead = Pass.refreshed(ledger(stock: 0, at: start), now: jump, timeZone: paris)
        XCTAssertEqual(ahead.stock, 1)
        XCTAssertEqual(ahead.lastSeen, jump)

        let back = start.addingTimeInterval(3600)
        XCTAssertEqual(verdict(ahead, back), .clockMoved)
        XCTAssertEqual(Pass.refreshed(ahead, now: back, timeZone: paris), ahead)
        XCTAssertEqual(verdict(ahead, jump.addingTimeInterval(-day)), .clockMoved)
        XCTAssertEqual(verdict(ahead, jump), .available)

        let spent = spend(ahead, jump)
        XCTAssertEqual(Pass.refreshed(spent, now: jump.addingTimeInterval(13 * day), timeZone: paris).stock, 0)
        XCTAssertEqual(Pass.refreshed(spent, now: jump.addingTimeInterval(14 * day), timeZone: paris).stock, 1)
    }

    func testTimeZoneChangeKeepsTheOldNight() {
        let one = ledger(stock: 1, at: at(2, 12))
        let parisNight = at(2, 23)
        XCTAssertEqual(verdict(one, parisNight, zone: newYork), .night)

        let moved = Pass.refreshed(one, now: parisNight, timeZone: newYork)
        XCTAssertEqual(moved.zoneID, newYork.identifier)
        XCTAssertEqual(moved.previousZoneID, paris.identifier)
        XCTAssertEqual(moved.zoneChangedAt, parisNight)
        XCTAssertEqual(verdict(moved, parisNight.addingTimeInterval(1800), zone: newYork), .night)
        XCTAssertEqual(verdict(moved, at(3, 23), zone: newYork), .available)
        XCTAssertEqual(verdict(moved, parisNight.addingTimeInterval(Policy.passZoneQuarantine - 60), zone: newYork), .night)
    }

    func testTimeZoneChangeAppliesTheNewNight() {
        let one = ledger(stock: 1, at: at(2, 12))
        XCTAssertEqual(verdict(one, at(2, 15)), .available)
        XCTAssertEqual(verdict(one, at(2, 15), zone: tokyo), .night)
    }

    func testTimeZoneHopsKeepTheFirstZone() {
        let one = ledger(stock: 1, at: at(2, 12))
        let first = Pass.refreshed(one, now: at(2, 22, 30), timeZone: newYork)
        let second = Pass.refreshed(first, now: at(2, 22, 40), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        XCTAssertEqual(second.previousZoneID, paris.identifier)
        XCTAssertEqual(verdict(second, at(2, 22, 45), zone: TimeZone(identifier: "America/Los_Angeles")!), .night)
    }

    func testTimeZoneChangeKeepsTheDayUsed() {
        let used = spend(ledger(stock: 2, at: at(2, 12)), at(2, 20))
        let nextDayInParis = at(3, 6, 30)
        XCTAssertEqual(verdict(used, nextDayInParis), .available)
        XCTAssertEqual(verdict(used, at(3, 3), zone: tokyo), .usedToday)
    }

    func testNothingBlocked() {
        let one = ledger(stock: 1, at: at(2, 12))
        XCTAssertEqual(verdict(one, at(2, 13), blocked: false), .nothingBlocked)
    }

    func testSuspended() {
        let one = ledger(stock: 1, at: at(2, 12))
        XCTAssertEqual(verdict(one, at(2, 13), suspended: true), .suspended)
    }

    func testOpenPass() {
        let opened = at(2, 13)
        let pass = ActivePass(groupID: UUID(), opened: opened, until: opened.addingTimeInterval(Policy.passDuration))
        let used = spend(ledger(stock: 2, at: at(2, 12)), opened)
        XCTAssertEqual(verdict(used, opened.addingTimeInterval(60), active: pass), .open(until: pass.until))
        XCTAssertEqual(verdict(used, pass.until, active: pass), .usedToday)
        XCTAssertFalse(pass.isOver(at: opened.addingTimeInterval(299)))
        XCTAssertTrue(pass.isOver(at: pass.until))
        XCTAssertFalse(pass.isOver(at: opened.addingTimeInterval(-Policy.passClockTolerance)))
        XCTAssertTrue(pass.isOver(at: opened.addingTimeInterval(-3600)))
        XCTAssertEqual(Policy.passDuration, 300)
        XCTAssertEqual(Policy.passAirlock, 30)
    }

    func testRefusalPriority() {
        let opened = at(2, 23)
        let pass = ActivePass(groupID: UUID(), opened: opened, until: opened.addingTimeInterval(Policy.passDuration))
        var worst = spend(ledger(stock: 1, at: at(2, 12)), at(2, 21))
        worst.lastSeen = at(3, 12)
        XCTAssertEqual(worst.stock, 0)

        XCTAssertEqual(verdict(worst, at(2, 23, 1), blocked: false, suspended: true, active: pass), .suspended)
        XCTAssertEqual(verdict(worst, at(2, 23, 1), blocked: false, active: pass), .open(until: pass.until))
        XCTAssertEqual(verdict(worst, at(2, 23, 1), blocked: false), .clockMoved)

        worst.lastSeen = at(2, 21)
        XCTAssertEqual(verdict(worst, at(2, 23, 1), blocked: false), .empty(next: at(2, 12).addingTimeInterval(Policy.passRefill)))

        worst.stock = 1
        XCTAssertEqual(verdict(worst, at(2, 23, 1), blocked: false), .usedToday)

        worst.lastUsedDay = nil
        XCTAssertEqual(verdict(worst, at(2, 23, 1), blocked: false), .night)
        XCTAssertEqual(verdict(worst, at(3, 7), blocked: false), .nothingBlocked)
        XCTAssertEqual(verdict(worst, at(3, 7)), .available)
    }

    func testAtMostOnePerEveningAndTwoPerFourteenDays() {
        for dayStart in [fourAM, DayStart()] {
            let start = at(2, 12)
            var current = ledger(stock: 2, at: start)
            var uses: [Date] = []
            for step in 0..<(60 * 48) {
                let now = start.addingTimeInterval(TimeInterval(step) * 1800)
                if verdict(current, now, dayStart: dayStart) == .available {
                    current = spend(current, now, dayStart: dayStart)
                    uses.append(now)
                } else {
                    current = Pass.refreshed(current, now: now, timeZone: paris)
                }
            }

            XCTAssertEqual(uses.count, 6)
            XCTAssertEqual(uses.filter { $0 < start.addingTimeInterval(Policy.passRefill) }.count, 2)
            for use in uses {
                let window = uses.filter { $0 >= use && $0 < use.addingTimeInterval(Policy.passRefill) }
                XCTAssertLessThanOrEqual(window.count, 2)
                XCTAssertFalse(Pass.isNight(use, calendar: calendar))
            }
            let evenings = Dictionary(grouping: uses) { fourAM.dayKey(for: $0, calendar: calendar) }
            XCTAssertTrue(evenings.values.allSatisfy { $0.count == 1 })
        }
    }

    func testPassActivityIsNotALimitActivity() {
        let pass = ActivePass(groupID: UUID(), opened: at(2, 13), until: at(2, 13, 5))
        XCTAssertNil(LimitGroup.id(from: pass.activityName))
        XCTAssertEqual(ActivePass.groupID(from: pass.activityName), pass.groupID)
        XCTAssertNil(ActivePass.groupID(from: LimitGroup(name: "Vidéo").activityName))
    }

    func testReminderChoices() {
        XCTAssertEqual(PassReminder.minuteBefore.notice?.lead, 60)
        XCTAssertEqual(PassReminder.minuteBefore.notice?.body, "Plus qu'une minute.")
        XCTAssertEqual(PassReminder.atEnd.notice?.lead, 0)
        XCTAssertEqual(PassReminder.atEnd.notice?.body, "C'est refermé.")
        XCTAssertNil(PassReminder.never.notice)
    }
}
