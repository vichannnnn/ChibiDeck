import Foundation
import Testing
@testable import PanelCore

@Suite struct FormatCanaryTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    static func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    @Test func absentForTenMinutesWithTwoObservationsIsFlagged() {
        var c = FormatCanary()
        c.observe(.feedContext, present: false, at: Self.at(0))
        c.observe(.feedContext, present: false, at: Self.at(300))
        #expect(c.warnings(at: Self.at(599)).isEmpty)
        #expect(c.warnings(at: Self.at(600)) == ["feed has no context_window — context bars"])
    }

    @Test func oneObservationIsNotEnough() {
        var c = FormatCanary()
        c.observe(.transcriptTitle, present: false, at: Self.at(0))
        #expect(c.warnings(at: Self.at(3600)).isEmpty)
    }

    @Test func aPresentObservationClearsAndTheClockStartsAgain() {
        var c = FormatCanary()
        c.observe(.feedModel, present: false, at: Self.at(0))
        c.observe(.feedModel, present: false, at: Self.at(700))
        #expect(c.warnings(at: Self.at(700)) == ["feed has no model — model chips"])
        c.observe(.feedModel, present: true, at: Self.at(710))
        #expect(c.warnings(at: Self.at(710)).isEmpty)
        c.observe(.feedModel, present: false, at: Self.at(720))
        c.observe(.feedModel, present: false, at: Self.at(730))
        #expect(c.warnings(at: Self.at(1000)).isEmpty)
    }

    @Test func aFieldNeverObservedIsNeverFlagged() {
        #expect(FormatCanary().warnings(at: Self.at(86_400)).isEmpty)
    }

    @Test func anUnknownStatusIsFlaggedAtOnceAndForgottenTenMinutesLater() {
        var c = FormatCanary()
        c.observeUnknownStatus("compacting", at: Self.at(0))
        #expect(c.warnings(at: Self.at(0)) == ["session status \u{201C}compacting\u{201D} is new to the panel — card status"])
        #expect(c.warnings(at: Self.at(599)).count == 1)
        #expect(c.warnings(at: Self.at(600)).isEmpty)
    }

    @Test func everyFieldNamesWhatItBreaks() {
        for field in FormatField.allCases { #expect(field.warning.contains(" — "), "\(field)") }
    }
}
