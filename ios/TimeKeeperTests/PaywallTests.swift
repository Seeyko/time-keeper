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
}
