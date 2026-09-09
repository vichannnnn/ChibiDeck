import Foundation
import Testing
@testable import PanelCore

@Suite struct AnswerResolverTests {
    static let question = PendingInput.question(text: "Pick a colour", options: ["Red", "Blue"])
    static let bash = PendingInput.permission(tool: "Bash", summary: "touch probe-3")
    static let replies = ["go", "yes", "no"]

    @Test func questionOptionsBecomeNumberedAnswers() {
        let a = AnswerResolver.answers(status: .waiting, waitingFor: "input needed", pending: Self.question, quickReplies: Self.replies)
        #expect(a == [Answer(label: "Red", text: "1"), Answer(label: "Blue", text: "2")])
        let five = PendingInput.question(text: "q", options: ["a", "b", "c", "d", "e"])
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: nil, pending: five, quickReplies: []).map(\.text) == ["1", "2", "3", "4"])
    }

    @Test func permissionPromptOffersAllow() {
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: "permission prompt", pending: nil, quickReplies: Self.replies) == [AnswerResolver.allow])
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: nil, pending: Self.bash, quickReplies: Self.replies) == [AnswerResolver.allow])
        #expect(AnswerResolver.allow.text == "")
        #expect(AnswerResolver.allow.label == "Allow ↵")
    }

    /// Final review: the session file is authoritative. A question read from a transcript up to 5 s old cannot make the
    /// panel type a number into a permission dialog, and `input needed` with a stale permission sends nothing at all.
    @Test func theSessionFileOutranksAStaleTranscript() {
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: "permission prompt", pending: Self.question, quickReplies: Self.replies)
                == [AnswerResolver.allow])
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: AnswerResolver.inputNeeded, pending: Self.bash, quickReplies: Self.replies).isEmpty)
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: AnswerResolver.inputNeeded, pending: Self.question, quickReplies: Self.replies)
                == [Answer(label: "Red", text: "1"), Answer(label: "Blue", text: "2")])
        #expect(AnswerResolver.inputNeeded == "input needed")
    }

    @Test func unrecognisedWaitOffersNothing() {
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: "input needed", pending: nil, quickReplies: Self.replies).isEmpty)
        #expect(AnswerResolver.answers(status: .waiting, waitingFor: nil, pending: nil, quickReplies: Self.replies).isEmpty)
    }

    @Test func idleOffersQuickReplies() {
        #expect(AnswerResolver.answers(status: .idle, waitingFor: nil, pending: nil, quickReplies: Self.replies)
                == [Answer(label: "go", text: "go"), Answer(label: "yes", text: "yes"), Answer(label: "no", text: "no")])
        #expect(AnswerResolver.answers(status: .idle, waitingFor: nil, pending: Self.bash, quickReplies: [" go ", "", "a", "b", "c", "d"]).map(\.text) == ["go", "a", "b", "c"])
    }

    @Test func busyShellBlockedUnknownOfferNothing() {
        for status in [SessionStatus.busy, .shell, .blocked, .unknown] {
            #expect(AnswerResolver.answers(status: status, waitingFor: "permission prompt", pending: Self.bash, quickReplies: Self.replies).isEmpty)
        }
    }

    @Test func cardPillKinds() {
        let qa = AnswerResolver.answers(status: .waiting, waitingFor: nil, pending: Self.question, quickReplies: [])
        #expect(AnswerResolver.cardPill(answers: qa, pending: Self.question) == AnswerResolver.CardPill(label: "2 opts ›", opensSheet: true))
        #expect(AnswerResolver.cardPill(answers: [AnswerResolver.allow], pending: Self.bash) == AnswerResolver.CardPill(label: "Allow ↵", opensSheet: false))
        #expect(AnswerResolver.cardPill(answers: [Answer(label: "go", text: "go")], pending: nil) == AnswerResolver.CardPill(label: "go", opensSheet: false))
        #expect(AnswerResolver.cardPill(answers: [], pending: nil) == nil)
        #expect(AnswerResolver.cardPill(answers: [], pending: PendingInput.question(text: "q", options: [])) == nil)
        // The label follows the answers, never the pending input: a stale question with `Allow ↵` answers still says Allow.
        #expect(AnswerResolver.cardPill(answers: [AnswerResolver.allow], pending: Self.question)
                == AnswerResolver.CardPill(label: "Allow ↵", opensSheet: false))
    }

    @Test func quickRepliesSettingParses() {
        #expect(AnswerResolver.quickReplies(from: "go, yes,,no") == ["go", "yes", "no"])
        #expect(AnswerResolver.quickReplies(from: "") == [])
        #expect(AnswerResolver.quickReplies(from: "a,b,c,d,e").count == 4)
    }
}
