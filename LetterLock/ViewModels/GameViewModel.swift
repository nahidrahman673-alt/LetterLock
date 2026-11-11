//
//  GameViewModel.swift
//  LetterLock
//

import Foundation
import Observation

@Observable
final class GameViewModel {
    // MARK: - Rules

    static let roundDuration = 60
    static let playerLimit = 2...8
    static let roundOptions = [3, 5]
    /// Once this many players lock in, the clock drops to `lockInCutSeconds`.
    static let lockInsToCutTimer = 3
    static let lockInCutSeconds = 5
    static let adDuration = 5
    static let roomCodeLength = 4

    static let pointsOriginal = 10
    static let pointsShared = 5

    static let letterPool = (UnicodeScalar("A").value...UnicodeScalar("Z").value)
        .compactMap { UnicodeScalar($0).map { String(Character($0)) } }
    private static let roomCodeCharacters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ").map(String.init)
    private static let testPlayerNames = ["Sam", "Priya", "Leo", "Maya", "Jonah", "Aisha", "Tom", "Ruth"]

    // MARK: - State

    var gameState: GameState = .home
    var categories = Category.defaults

    private(set) var roomCode = ""
    private(set) var players: [Player] = []
    var totalRounds = 3
    private(set) var currentRound = 0

    // Letter choice
    private(set) var currentLetter = "?"
    private(set) var isShuffling = false
    private(set) var hasChosenLetter = false
    var isShowingAd = false
    private(set) var adSecondsRemaining = 0

    // Round in play
    private(set) var timeRemaining = GameViewModel.roundDuration
    var answers: [UUID: String] = [:]
    private(set) var lockedInPlayerIds: Set<UUID> = []
    private(set) var wasTimerCut = false

    // Reveal
    private(set) var roundAnswers: [RoundAnswer] = []
    private(set) var activeVote: VetoVote?

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var shuffleTask: Task<Void, Never>?
    @ObservationIgnored private var adTask: Task<Void, Never>?
    @ObservationIgnored private var voteTask: Task<Void, Never>?
    /// For each simulated player, the seconds-remaining mark at which they lock in.
    @ObservationIgnored private var botLockInMarks: [UUID: Int] = [:]

    // MARK: - Derived

    var localPlayer: Player? { players.first(where: \.isLocal) }
    var hostPlayer: Player? { players.first(where: \.isHost) }
    var isLocalHost: Bool { localPlayer?.isHost ?? false }

    /// Players take turns choosing the letter, starting with the first player.
    var letterChooser: Player? {
        guard !players.isEmpty, currentRound > 0 else { return nil }
        return players[(currentRound - 1) % players.count]
    }

    var isLocalChooser: Bool { letterChooser?.isLocal ?? false }
    var isLastRound: Bool { currentRound >= totalRounds }
    var canStartGame: Bool { Self.playerLimit.contains(players.count) }
    var canAddPlayer: Bool { players.count < Self.playerLimit.upperBound }

    var isLocalLockedIn: Bool {
        guard let localPlayer else { return false }
        return lockedInPlayerIds.contains(localPlayer.id)
    }

    var isInputFrozen: Bool { gameState != .playing || isLocalLockedIn }

    func roundPoints(for playerId: UUID) -> Int {
        roundAnswers.filter { $0.playerId == playerId }.reduce(0) { $0 + $1.points }
    }

    /// Players sorted by total score, including the round being revealed.
    var standings: [(player: Player, total: Int)] {
        players
            .map { ($0, $0.score + (gameState == .reveal ? roundPoints(for: $0.id) : 0)) }
            .sorted { $0.1 > $1.1 }
    }

    func answers(for categoryId: UUID) -> [RoundAnswer] {
        roundAnswers.filter { $0.categoryId == categoryId }
    }

    func player(_ id: UUID) -> Player? { players.first { $0.id == id } }

    func answer(_ id: UUID) -> RoundAnswer? { roundAnswers.first { $0.id == id } }

    func categoryName(for id: UUID) -> String {
        categories.first { $0.id == id }?.name ?? ""
    }

    // MARK: - Home and lobby

    func startNewGame() {
        resetMatch()
        roomCode = Self.makeRoomCode()
        players = Self.mockPlayers(localPlayerIsHost: true)
        gameState = .lobby
    }

    func joinGame(code: String) {
        guard Self.isValidRoomCode(code) else { return }
        resetMatch()
        roomCode = Self.normalizedRoomCode(code)
        players = Self.mockPlayers(localPlayerIsHost: false)
        gameState = .lobby
    }

    /// Prototype only: stands in for a friend joining with the room code.
    func addTestPlayer() {
        guard canAddPlayer else { return }
        let taken = Set(players.map(\.name))
        let name = Self.testPlayerNames.first { !taken.contains($0) } ?? "Player \(players.count + 1)"
        players.append(Player(name: name, isReady: true))
    }

    /// Prototype only: removes the most recent simulated player.
    func removeTestPlayer() {
        guard players.count > Self.playerLimit.lowerBound,
              let index = players.lastIndex(where: { !$0.isLocal && !$0.isHost }) else { return }
        players.remove(at: index)
    }

    /// Host only.
    func startGame(by playerId: UUID) {
        guard isHost(playerId), canStartGame else { return }
        for index in players.indices { players[index].score = 0 }
        currentRound = 1
        beginLetterChoice()
    }

    // MARK: - Letter choice

    private func beginLetterChoice() {
        cancelTasks()
        currentLetter = "?"
        hasChosenLetter = false
        isShuffling = false
        gameState = .choosingLetter

        // Simulated choosers shuffle on their own after a beat.
        if !isLocalChooser {
            shuffleTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                self?.runShuffle()
            }
        }
    }

    /// Only the round's chooser can shuffle.
    func shuffleLetter() {
        guard isLocalChooser, !hasChosenLetter else { return }
        runShuffle()
    }

    /// Prototype stand-in for a rewarded ad. The reshuffle runs once the ad is closed.
    func watchAdToReshuffle() {
        guard isLocalChooser, hasChosenLetter, !isShuffling else { return }
        adSecondsRemaining = Self.adDuration
        isShowingAd = true
        adTask = Task { [weak self] in
            while let self, self.adSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.adSecondsRemaining -= 1
            }
        }
    }

    func closeAd() {
        guard adSecondsRemaining == 0 else { return }
        isShowingAd = false
        runShuffle()
    }

    /// Flicks through random tiles, slowing down, then lands on the final letter.
    private func runShuffle() {
        guard !isShuffling, gameState == .choosingLetter else { return }
        isShuffling = true
        hasChosenLetter = false
        let finalLetter = Self.letterPool.randomElement() ?? "A"

        shuffleTask = Task { [weak self] in
            let flicks = 18
            for step in 0..<flicks {
                try? await Task.sleep(for: .milliseconds(45 + step * step))
                guard let self, !Task.isCancelled else { return }
                var next = Self.letterPool.randomElement() ?? "A"
                while next == self.currentLetter { next = Self.letterPool.randomElement() ?? "A" }
                self.currentLetter = next
            }
            try? await Task.sleep(for: .milliseconds(380))
            guard let self, !Task.isCancelled else { return }
            self.currentLetter = finalLetter
            self.isShuffling = false
            self.hasChosenLetter = true
        }
    }

    // MARK: - Round

    /// Host only, once the letter is set.
    func startRound(by playerId: UUID) {
        guard isHost(playerId), gameState == .choosingLetter, hasChosenLetter else { return }
        cancelTasks()
        timeRemaining = Self.roundDuration
        answers = [:]
        lockedInPlayerIds = []
        wasTimerCut = false
        roundAnswers = []
        activeVote = nil
        botLockInMarks = Dictionary(uniqueKeysWithValues: players.filter { !$0.isLocal }.map {
            ($0.id, Int.random(in: 12...48))
        })
        gameState = .playing
        startTimer()
    }

    func lockIn() {
        guard let localPlayer, gameState == .playing else { return }
        lockIn(localPlayer.id)
    }

    private func lockIn(_ playerId: UUID) {
        guard !lockedInPlayerIds.contains(playerId) else { return }
        lockedInPlayerIds.insert(playerId)
        if lockedInPlayerIds.count >= Self.lockInsToCutTimer, timeRemaining > Self.lockInCutSeconds {
            timeRemaining = Self.lockInCutSeconds
            wasTimerCut = true
        }
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self else { return }
                self.timeRemaining -= 1
                for (id, mark) in self.botLockInMarks where self.timeRemaining <= mark {
                    self.lockIn(id)
                }
                if self.timeRemaining <= 0 {
                    self.endRound()
                    return
                }
            }
        }
    }

    private func endRound() {
        guard gameState == .playing else { return }
        timerTask?.cancel()
        timerTask = nil
        roundAnswers = players.flatMap { player in
            categories.map { category in
                let text = player.isLocal
                    ? answers[category.id, default: ""]
                    : MockAnswerBank.answer(for: category.name, letter: currentLetter)
                return RoundAnswer(
                    playerId: player.id,
                    categoryId: category.id,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
        scoreRound()
        gameState = .reveal
    }

    // MARK: - Reveal, veto and scoring

    /// Blank or rejected answers score 0. Otherwise: unique +10, exactly two the same +5, three or more 0.
    private func scoreRound() {
        let counted = roundAnswers.filter { !$0.isBlank && $0.verdict == .accepted }
        var matches: [String: Int] = [:]
        for answer in counted {
            matches["\(answer.categoryId)|\(answer.matchKey)", default: 0] += 1
        }
        for index in roundAnswers.indices {
            let answer = roundAnswers[index]
            guard !answer.isBlank, answer.verdict == .accepted else {
                roundAnswers[index].points = 0
                continue
            }
            switch matches["\(answer.categoryId)|\(answer.matchKey)", default: 1] {
            case 1: roundAnswers[index].points = Self.pointsOriginal
            case 2: roundAnswers[index].points = Self.pointsShared
            default: roundAnswers[index].points = 0
            }
        }
    }

    func canVeto(_ answer: RoundAnswer) -> Bool {
        gameState == .reveal && activeVote == nil && !answer.isBlank && !answer.wasVoted
            && answer.playerId != localPlayer?.id
    }

    /// Starts a vote among everyone except the answer's author.
    func veto(_ answerId: UUID) {
        guard let answer = answer(answerId), canVeto(answer) else { return }
        let voters = players.filter { $0.id != answer.playerId }.map(\.id)
        activeVote = VetoVote(answerId: answerId, voterIds: voters)

        // Simulated players vote over the next couple of seconds.
        let bots = players.filter { !$0.isLocal && voters.contains($0.id) }.map(\.id)
        voteTask = Task { [weak self] in
            for id in bots.shuffled() {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 400...1100)))
                guard let self, !Task.isCancelled else { return }
                self.recordBallot(from: id, accept: Double.random(in: 0..<1) < 0.55)
            }
        }
    }

    func castVote(accept: Bool) {
        guard let localPlayer else { return }
        recordBallot(from: localPlayer.id, accept: accept)
    }

    func hasLocalVoted() -> Bool {
        guard let localPlayer, let activeVote else { return false }
        return activeVote.ballots[localPlayer.id] != nil || !activeVote.voterIds.contains(localPlayer.id)
    }

    private func recordBallot(from playerId: UUID, accept: Bool) {
        guard var vote = activeVote, vote.voterIds.contains(playerId), vote.ballots[playerId] == nil else { return }
        vote.ballots[playerId] = accept
        activeVote = vote
        guard vote.isComplete, let index = roundAnswers.firstIndex(where: { $0.id == vote.answerId }) else { return }
        roundAnswers[index].verdict = vote.verdict
        roundAnswers[index].wasVoted = true
        scoreRound()
    }

    func dismissVote() {
        guard activeVote?.isComplete ?? true else { return }
        voteTask?.cancel()
        activeVote = nil
    }

    /// Host only. Banks the round's points, then moves to the next letter or the final results.
    func nextRound(by playerId: UUID) {
        guard isHost(playerId), gameState == .reveal else { return }
        cancelTasks()
        activeVote = nil
        for index in players.indices {
            players[index].score += roundPoints(for: players[index].id)
        }
        roundAnswers = []
        if isLastRound {
            gameState = .finalResults
        } else {
            currentRound += 1
            beginLetterChoice()
        }
    }

    /// Host only. Back to the lobby with the same players.
    func playAgain(by playerId: UUID) {
        guard isHost(playerId) else { return }
        resetMatch()
        gameState = .lobby
    }

    func resetToHome() {
        resetMatch()
        roomCode = ""
        players = []
        gameState = .home
    }

    // MARK: - Helpers

    static func normalizedRoomCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValidRoomCode(_ code: String) -> Bool {
        let normalized = normalizedRoomCode(code)
        return normalized.count == roomCodeLength && normalized.allSatisfy { $0.isLetter || $0.isNumber }
    }

    private func isHost(_ playerId: UUID) -> Bool {
        player(playerId)?.isHost ?? false
    }

    private func cancelTasks() {
        for task in [timerTask, shuffleTask, adTask, voteTask] { task?.cancel() }
        timerTask = nil
        shuffleTask = nil
        adTask = nil
        voteTask = nil
    }

    private func resetMatch() {
        cancelTasks()
        currentRound = 0
        currentLetter = "?"
        hasChosenLetter = false
        isShuffling = false
        isShowingAd = false
        timeRemaining = Self.roundDuration
        answers = [:]
        lockedInPlayerIds = []
        wasTimerCut = false
        roundAnswers = []
        activeVote = nil
        for index in players.indices { players[index].score = 0 }
    }

    private static func makeRoomCode() -> String {
        (0..<roomCodeLength).compactMap { _ in roomCodeCharacters.randomElement() }.joined()
    }

    private static func mockPlayers(localPlayerIsHost: Bool) -> [Player] {
        [
            Player(name: "You", isHost: localPlayerIsHost, isReady: true, isLocal: true),
            Player(name: "Sam", isHost: !localPlayerIsHost, isReady: true),
            Player(name: "Priya", isReady: true),
            Player(name: "Leo", isReady: true),
        ]
    }
}

// MARK: - SwiftUI previews

extension GameViewModel {
    static func preview(_ state: GameState) -> GameViewModel {
        let viewModel = GameViewModel()
        guard state != .home else { return viewModel }

        viewModel.startNewGame()
        guard state != .lobby, let host = viewModel.hostPlayer else { return viewModel }

        viewModel.startGame(by: host.id)
        guard state != .choosingLetter else { return viewModel }

        viewModel.currentLetter = "S"
        viewModel.hasChosenLetter = true
        viewModel.startRound(by: host.id)
        if let first = viewModel.categories.first {
            viewModel.answers[first.id] = "Sam"
        }
        guard state != .playing else { return viewModel }

        viewModel.endRound()
        if state == .finalResults {
            viewModel.nextRound(by: host.id)
            viewModel.gameState = .finalResults
        }
        return viewModel
    }
}
