import XCTest
@testable import TimeKeeper

final class PaywallTests: XCTestCase {
    func testYearlyWithTrialSaysThePriceAfterTheTrial() {
        XCTAssertEqual(Plan.yearly.cta(trial: true), "Essayer 7 jours gratuits")
        XCTAssertEqual(Plan.yearly.terms(price: "19,99 €", trial: true), "Puis 19,99 € par an. Annulable à tout moment.")
    }

    func testYearlyWithoutTrialPromisesNoTrial() {
        XCTAssertEqual(Plan.yearly.cta(trial: false), "Continuer")
        XCTAssertEqual(Plan.yearly.terms(price: "19,99 €", trial: false), "19,99 € par an. Annulable à tout moment.")
    }

    func testLifetimeIsNeverATrial() {
        XCTAssertEqual(Plan.lifetime.cta(trial: true), "Continuer")
        XCTAssertEqual(Plan.lifetime.terms(price: "39,99 €", trial: true), "39,99 € une seule fois. Aucun abonnement.")
    }

    func testTrialReminderComesBeforeTheFirstPayment() {
        XCTAssertLessThan(Plan.trialReminderDay, Plan.trialDays)
    }

    func testTestFlightEuroPricesMatchTheStore() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "TimeKeeper.storekit")
        let text = try String(contentsOf: file, encoding: .utf8)
        for plan in Plan.allCases {
            let price = String(format: "%d.%02d", plan.euroCents / 100, plan.euroCents % 100)
            XCTAssertTrue(text.contains("\"displayPrice\" : \"\(price)\""), plan.rawValue)
        }
    }
}
