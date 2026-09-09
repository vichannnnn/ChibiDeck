import Foundation
import Testing
@testable import PanelCore

@Suite struct HandoffSequencerTests {
    static let t0 = Date(timeIntervalSince1970: 1_000_000)
    static let reply = "Handoff below.\n\n```\nYou are continuing work.\n```"
    typealias O = HandoffSequencer.Observation

    static func fresh() -> HandoffSequencer { HandoffSequencer(pid: 42, sessionId: "old", requestedAt: t0) }
    static func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    @Test func waitsWhileBusyOrWaitingThenCapturesTheReplyAndAsksForClear() {
        var seq = Self.fresh()
        #expect(seq.observe(O(pidAlive: true, sessionId: "old", status: .busy, handoffReply: nil, handoffReplyAt: nil), now: Self.at(2)) == nil)
        #expect(seq.observe(O(pidAlive: true, sessionId: "old", status: .waiting, handoffReply: nil, handoffReplyAt: nil), now: Self.at(4)) == nil)
        #expect(seq.observe(O(pidAlive: true, sessionId: "old", status: .busy, handoffReply: Self.reply, handoffReplyAt: Self.at(5)), now: Self.at(6)) == nil)  // text written, turn not over
        #expect(seq.phase == .requested && seq.isActive)
        let cmd = seq.observe(O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: Self.reply, handoffReplyAt: Self.at(5)), now: Self.at(8))
        #expect(cmd == .typeClear)
        #expect(seq.phase == .clearing && seq.isActive)
        #expect(seq.block == "You are continuing work.")
    }

    @Test func aReplyWithoutAFenceNeverClears() {
        var seq = Self.fresh()
        let bare = O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: "You've reached your limit.", handoffReplyAt: Self.at(5))
        #expect(seq.observe(bare, now: Self.at(6)) == nil)
        #expect(seq.phase == .requested && seq.block == nil)
        let waiting = O(pidAlive: true, sessionId: "old", status: .waiting, handoffReply: Self.reply, handoffReplyAt: Self.at(5))
        #expect(seq.observe(waiting, now: Self.at(7)) == nil)                 // a dialog is up: the turn is not over
    }

    @Test func aReplyOlderThanTheRequestIsIgnored() {
        var seq = Self.fresh()
        let stale = O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: Self.reply, handoffReplyAt: Self.at(-30))
        #expect(seq.observe(stale, now: Self.at(1)) == nil)
        let undated = O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: Self.reply, handoffReplyAt: nil)
        #expect(seq.observe(undated, now: Self.at(2)) == nil)
        #expect(seq.phase == .requested)
    }

    @Test func sessionClearedOrExitedWhileWaitingFails() {
        var cleared = Self.fresh()
        #expect(cleared.observe(O(pidAlive: true, sessionId: "new", status: .idle, handoffReply: nil, handoffReplyAt: nil), now: Self.at(3)) == .fail("session cleared"))
        #expect(cleared.phase == .failed("session cleared") && !cleared.isActive)
        var exited = Self.fresh()
        #expect(exited.observe(O(pidAlive: false, sessionId: nil, status: nil, handoffReply: nil, handoffReplyAt: nil), now: Self.at(3)) == .fail("session exited"))
        var unreadable = Self.fresh()                                        // a momentarily unreadable file is not a clear
        #expect(unreadable.observe(O(pidAlive: true, sessionId: nil, status: nil, handoffReply: nil, handoffReplyAt: nil), now: Self.at(3)) == nil)
        #expect(unreadable.phase == .requested)
    }

    @Test func replyTimeoutFails() {
        var seq = Self.fresh()
        let quiet = O(pidAlive: true, sessionId: "old", status: .busy, handoffReply: nil, handoffReplyAt: nil)
        #expect(seq.observe(quiet, now: Self.at(HandoffSequencer.replyTimeout)) == nil)
        #expect(seq.observe(quiet, now: Self.at(HandoffSequencer.replyTimeout + 1)) == .fail("no handoff reply"))
    }

    static func clearing() -> HandoffSequencer {
        var seq = fresh()
        _ = seq.observe(O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: reply, handoffReplyAt: at(5)), now: at(8))
        return seq
    }

    @Test func pastesOnceTheNewSessionIsIdle() {
        var seq = Self.clearing()
        #expect(seq.observe(O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: Self.reply, handoffReplyAt: Self.at(5)), now: Self.at(9)) == nil)
        #expect(seq.observe(O(pidAlive: true, sessionId: "new", status: .busy, handoffReply: nil, handoffReplyAt: nil), now: Self.at(10)) == nil)
        #expect(seq.observe(O(pidAlive: true, sessionId: "new", status: .idle, handoffReply: nil, handoffReplyAt: nil), now: Self.at(11)) == .paste("You are continuing work."))
        #expect(seq.phase == .done && !seq.isActive)
        #expect(seq.observe(O(pidAlive: true, sessionId: "new", status: .idle, handoffReply: nil, handoffReplyAt: nil), now: Self.at(12)) == nil)
    }

    @Test func clearTimeoutAndExitWhileClearingFail() {
        var late = Self.clearing()
        let same = O(pidAlive: true, sessionId: "old", status: .idle, handoffReply: Self.reply, handoffReplyAt: Self.at(5))
        #expect(late.observe(same, now: Self.at(8 + HandoffSequencer.clearTimeout)) == nil)
        #expect(late.observe(same, now: Self.at(8 + HandoffSequencer.clearTimeout + 1)) == .fail("clear didn't happen"))
        var gone = Self.clearing()
        #expect(gone.observe(O(pidAlive: false, sessionId: nil, status: nil, handoffReply: nil, handoffReplyAt: nil), now: Self.at(9)) == .fail("session exited"))
    }

    @Test func abortEndsTheSequence() {
        var seq = Self.clearing()
        seq.abort("Terminal didn't answer")
        #expect(seq.phase == .failed("Terminal didn't answer") && !seq.isActive)
        #expect(seq.observe(O(pidAlive: true, sessionId: "new", status: .idle, handoffReply: nil, handoffReplyAt: nil), now: Self.at(20)) == nil)
    }
}
