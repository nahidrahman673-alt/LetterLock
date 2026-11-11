//
//  GameModels.swift
//  LetterLock
//

import Foundation

enum GameState: Equatable {
    case home
    case lobby
    /// The round's chooser shuffles for a letter, then the host starts the round.
    case choosingLetter
    case playing
    case reveal
    case finalResults
}

struct Category: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    static let defaults: [Category] = [
        "Boy's Name",
        "Girl's Name",
        "Country",
        "City",
        "Animal",
        "Food/Drink",
        "Movies/Series",
        "Book/Movie Character",
        "Celebrity",
        "Brand",
    ].map { Category(name: $0) }
}

struct Player: Identifiable, Hashable {
    let id: UUID
    var name: String
    var score: Int
    var isHost: Bool
    var isReady: Bool
    /// True for the person holding this phone. Everyone else is simulated in the prototype.
    var isLocal: Bool

    init(
        id: UUID = UUID(),
        name: String,
        score: Int = 0,
        isHost: Bool = false,
        isReady: Bool = false,
        isLocal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.isHost = isHost
        self.isReady = isReady
        self.isLocal = isLocal
    }
}

enum AnswerVerdict: Equatable {
    /// Counts unless someone vetoes it and the vote rejects it.
    case accepted
    case rejected
}

/// One player's answer for one category in the current round.
struct RoundAnswer: Identifiable, Hashable {
    let id: UUID
    var playerId: UUID
    var categoryId: UUID
    var text: String
    var verdict: AnswerVerdict
    /// True once a veto vote has run on this answer, so it can't be vetoed twice.
    var wasVoted: Bool
    var points: Int

    init(
        id: UUID = UUID(),
        playerId: UUID,
        categoryId: UUID,
        text: String,
        verdict: AnswerVerdict = .accepted,
        wasVoted: Bool = false,
        points: Int = 0
    ) {
        self.id = id
        self.playerId = playerId
        self.categoryId = categoryId
        self.text = text
        self.verdict = verdict
        self.wasVoted = wasVoted
        self.points = points
    }

    var isBlank: Bool { text.isEmpty }

    /// Spelling is left to the players, so answers match on case and spacing only.
    var matchKey: String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// A vote started by tapping Veto on an answer. Everyone except the answer's author votes.
struct VetoVote: Identifiable, Equatable {
    let id = UUID()
    let answerId: UUID
    let voterIds: [UUID]
    var ballots: [UUID: Bool] = [:]

    var acceptCount: Int { ballots.values.filter { $0 }.count }
    var rejectCount: Int { ballots.values.filter { !$0 }.count }
    var isComplete: Bool { ballots.count == voterIds.count }

    /// Majority rejects. A tie keeps the answer.
    var verdict: AnswerVerdict { rejectCount > acceptCount ? .rejected : .accepted }
}
