import XCTest
@testable import TimeKeeper

final class RulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(_ minutes: Int = 30, domains: [String] = ["youtube.com"]) -> (TimeKeeperState, LimitGroup) {
        let group = LimitGroup(name: "Réseaux", minutes: minutes)
        var rules = Rules()
        rules.groups = [group]
        rules.blockedDomains = domains
        return (TimeKeeperState(active: rules), group)
    }

    func testLowerLimitAppliesNow() {
        let (s, g) = state()
        var draft = s.active
        draft.groups[0].minutes = 15
        let out = Engine.plan(s, draft: draft, now: now)
        XCTAssertNil(out.pending)
        XCTAssertEqual(out.active.groups.first { $0.id == g.id }?.minutes, 15)
    }

    func testHigherLimitWaits24Hours() {
        let (s, g) = state()
        var draft = s.active
        draft.groups[0].minutes = 60
        let out = Engine.plan(s, draft: draft, now: now)
        XCTAssertEqual(out.active.groups.first { $0.id == g.id }?.minutes, 30)
        XCTAssertEqual(out.pending?.groups.first?.minutes, 60)
        XCTAssertEqual(out.pendingEffective, now.addingTimeInterval(Policy.loosenDelay))
    }

    func testDeletingLimitWaits() {
        let (s, _) = state()
        var draft = s.active
        draft.groups = []
        let out = Engine.plan(s, draft: draft, now: now)
        XCTAssertEqual(out.active.groups.count, 1)
        XCTAssertEqual(out.pending?.groups.count, 0)
    }

    func testAddingLimitAppliesNow() {
        let (s, _) = state()
        var draft = s.active
        draft.groups.append(LimitGroup(name: "Jeux", minutes: 10))
        let out = Engine.plan(s, draft: draft, now: now)
        XCTAssertNil(out.pending)
        XCTAssertEqual(out.active.groups.count, 2)
    }

    func testDomainAddNowRemoveLater() {
        let (s, _) = state()
        var add = s.active
        add.blockedDomains.append("instagram.com")
        let added = Engine.plan(s, draft: add, now: now)
        XCTAssertNil(added.pending)
        XCTAssertEqual(added.active.blockedDomains, ["youtube.com", "instagram.com"])

        var remove = added.active
        remove.blockedDomains = ["instagram.com"]
        let removed = Engine.plan(added, draft: remove, now: now)
        XCTAssertTrue(removed.active.blockedDomains.contains("youtube.com"))
        XCTAssertEqual(removed.pending?.blockedDomains, ["instagram.com"])
    }

    func testLockOnNowOffLater() {
        let (s, _) = state()
        var on = s.active
        on.denyAppRemoval = true
        let locked = Engine.plan(s, draft: on, now: now)
        XCTAssertTrue(locked.active.denyAppRemoval)
        XCTAssertNil(locked.pending)

        var off = locked.active
        off.denyAppRemoval = false
        let unlocked = Engine.plan(locked, draft: off, now: now)
        XCTAssertTrue(unlocked.active.denyAppRemoval)
        XCTAssertEqual(unlocked.pending?.denyAppRemoval, false)
    }

    func testDayStartChangeWaits() {
        let (s, _) = state()
        var draft = s.active
        draft.dayStart = DayStart(hour: 4, minute: 0)
        let out = Engine.plan(s, draft: draft, now: now)
        XCTAssertEqual(out.active.dayStart, DayStart())
        XCTAssertEqual(out.pending?.dayStart, DayStart(hour: 4, minute: 0))
    }

    func testPendingAppliesOnlyAfterDelay() {
        let (s, _) = state()
        var draft = s.active
        draft.groups[0].minutes = 60
        let planned = Engine.plan(s, draft: draft, now: now)
        XCTAssertEqual(Engine.promote(planned, now: now.addingTimeInterval(3600)).active.groups[0].minutes, 30)
        let promoted = Engine.promote(planned, now: now.addingTimeInterval(Policy.loosenDelay))
        XCTAssertEqual(promoted.active.groups[0].minutes, 60)
        XCTAssertNil(promoted.pending)
    }

    func testTighteningPendingKeepsTimer() {
        let (s, _) = state()
        var loose = s.active
        loose.groups[0].minutes = 90
        let first = Engine.plan(s, draft: loose, now: now)

        var lessLoose = loose
        lessLoose.groups[0].minutes = 60
        let second = Engine.plan(first, draft: lessLoose, now: now.addingTimeInterval(3600))
        XCTAssertEqual(second.pendingEffective, first.pendingEffective)

        var looser = lessLoose
        looser.groups[0].minutes = 120
        let third = Engine.plan(second, draft: looser, now: now.addingTimeInterval(7200))
        XCTAssertEqual(third.pendingEffective, now.addingTimeInterval(7200 + Policy.loosenDelay))
    }

    func testCancelPending() {
        let (s, _) = state()
        var draft = s.active
        draft.groups[0].minutes = 60
        let planned = Engine.plan(s, draft: draft, now: now)
        let cancelled = Engine.plan(planned, draft: planned.active, now: now)
        XCTAssertNil(cancelled.pending)
        XCTAssertNil(cancelled.pendingEffective)
    }

    func testNormalizeDomain() {
        XCTAssertEqual(Rules.normalizeDomain("https://www.YouTube.com/watch?v=1"), "youtube.com")
        XCTAssertEqual(Rules.normalizeDomain(" instagram.com "), "instagram.com")
        XCTAssertEqual(Rules.normalizeDomain("m.facebook.com:443"), "m.facebook.com")
        XCTAssertNil(Rules.normalizeDomain("youtube"))
        XCTAssertNil(Rules.normalizeDomain("you tube.com"))
    }

    func testFilteredDomainsAddVariantsAndCap() {
        XCTAssertEqual(Set(Engine.filteredDomainNames(["youtube.com"])), ["youtube.com", "www.youtube.com", "m.youtube.com"])
        let many = (0..<40).map { "site\($0).com" }
        XCTAssertEqual(Engine.filteredDomainNames(many).count, Policy.maxFilteredDomains)
        XCTAssertEqual(Array(Engine.filteredDomainNames(many).prefix(40)), many)
    }

    func testDayStartInterval() {
        XCTAssertEqual(DayStart().intervalEnd, DateComponents(hour: 23, minute: 59, second: 59))
        XCTAssertEqual(DayStart(hour: 4, minute: 30).intervalEnd, DateComponents(hour: 4, minute: 29, second: 59))
    }

    func testDayKeyFollowsDayStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let twoAM = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 2))!
        XCTAssertEqual(DayStart().dayKey(for: twoAM, calendar: calendar), "2026-11-22")
        XCTAssertEqual(DayStart(hour: 4, minute: 0).dayKey(for: twoAM, calendar: calendar), "2026-11-21")
    }
}
