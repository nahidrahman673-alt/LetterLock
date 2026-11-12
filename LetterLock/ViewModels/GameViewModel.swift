//
//  GameViewModel.swift
//  LetterLock
//

import Foundation
import Observation

@Observable
final class GameViewModel {
    // MARK: - Rules

    static let playerLimit = 2...8
    /// First option is the default.
    static let roundOptions = [5, 3]
    static let timerOptions = [90, 60]
    /// Once this many players lock in, the clock drops to `lockInCutSeconds`.
    static let lockInsToCutTimer = 3
    static let lockInCutSeconds = 5
    /// Ticks play for the last few seconds of every round.
    static let countdownSeconds = 5
    static let adDuration = 5
    static let roomCodeLength = 4

    static let pointsOriginal = 10
    static let pointsShared = 5

    static let reactionEmoji = ["😂", "🤔", "🔥", "💀", "👏"]

    static let letterPool = (UnicodeScalar("A").value...UnicodeScalar("Z").value)
        .compactMap { UnicodeScalar($0).map { String(Character($0)) } }
    private static let roomCodeCharacters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ").map(String.init)
    private static let testPlayerNames = ["Sam", "Priya", "Leo", "Maya", "Jonah", "Aisha", "Tom", "Ruth"]

    // MARK: - State

    var gameState: GameState = .home
    var categories = Category.defaults
    @ObservationIgnored var sounds: SoundPlaying = SilentSoundPlayer()

    private(set) var roomCode = ""
    private(set) var players: [Player] = []
    var totalRounds = GameViewModel.roundOptions[0]
    var roundSeconds = GameViewModel.timerOptions[0]
    var shuffleStyle: ShuffleStyle = .rain
    private(set) var currentRound = 0

    // Letter choice
    private(set) var currentLetter = "?"
    private(set) var isShuffling = false
    private(set) var hasChosenLetter = false
    var isShowingAd = false
    private(set) var adSecondsRemaining = 0

    // Round in play
    private(set) var timeRemaining = GameViewModel.timerOptions[0]
    var answers: [UUID: String] = [:]
    private(set) var lockedInPlayerIds: Set<UUID> = []
    private(set) var wasTimerCut = false

    // Reveal: one category at a time, answers appearing one by one.
    private(set) var roundAnswers: [RoundAnswer] = []
    private(set) var activeVote: VetoVote?
    /// Equal to `categories.count` once every category is done and the scores are showing.
    private(set) var revealCategoryIndex = 0
    private(set) var revealedAnswerCount = 0
    /// Points for the current category show only once all its answers are out.
    private(set) var isCategoryScored = false
    private(set) var reactions: [Reaction] = []

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var shuffleTask: Task<Void, Never>?
    @ObservationIgnored private var adTask: Task<Void, Never>?
    @ObservationIgnored private var voteTask: Task<Void, Never>?
    @ObservationIgnored private var revealTask: Task<Void, Never>?
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

    var revealCategory: Category? {
        categories.indices.contains(revealCategoryIndex) ? categories[revealCategoryIndex] : nil
    }

    var isShowingRoundScores: Bool { gameState == .reveal && revealCategoryIndex >= categories.count }
    var isLastRevealCategory: Bool { revealCategoryIndex == categories.count - 1 }

    func roundPoints(for playerId: UUID) -> Int {
        roundAnswers.filter { $0.playerId == playerId }.reduce(0) { $0 + $1.points }
    }

    /// Players sorted by total score, including the round being revealed.
    var standings: [(player: Player, total: Int)] {
        players
            .map { ($0, $0.score + (gameState == .reveal ? roundPoints(for: $0.id) : 0)) }
            .sorted { $0.1 > $1.1 }
    }

    /// In player order, so answers reveal Player 1, Player 2, and so on.
    func answers(for categoryId: UUID) -> [RoundAnswer] {
        roundAnswers.filter { $0.categoryId == categoryId }
    }

    func isRevealed(_ answer: RoundAnswer) -> Bool {
        guard let index = categories.firstIndex(where: { $0.id == answer.categoryId }) else { return false }
        if index != revealCategoryIndex { return index < revealCategoryIndex }
        let position = answers(for: answer.categoryId).firstIndex { $0.id == answer.id } ?? .max
        return position < revealedAnswerCount
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
        sounds.setMusicDucked(true)
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
        sounds.setMusicDucked(false)
        runShuffle()
    }

    /// Flicks through random letters, slowing down, then lands on the final one.
    /// The view turns each flick into tiles scrambling past each other.
    private func runShuffle() {
        guard !isShuffling, gameState == .choosingLetter else { return }
        isShuffling = true
        hasChosenLetter = false
        let finalLetter = Self.letterPool.randomElement() ?? "A"

        shuffleTask = Task { [weak self] in
            let flicks = 16
            for step in 0..<flicks {
                try? await Task.sleep(for: .milliseconds(90 + step * step))
                guard let self, !Task.isCancelled else { return }
                var next = Self.letterPool.randomElement() ?? "A"
                while next == self.currentLetter { next = Self.letterPool.randomElement() ?? "A" }
                self.currentLetter = next
                self.sounds.play(.clack)
            }
            try? await Task.sleep(for: .milliseconds(420))
            guard let self, !Task.isCancelled else { return }
            self.currentLetter = finalLetter
            self.isShuffling = false
            self.hasChosenLetter = true
            self.sounds.play(.land)
        }
    }

    // MARK: - Round

    /// Host only, once the letter is set.
    func startRound(by playerId: UUID) {
        guard isHost(playerId), gameState == .choosingLetter, hasChosenLetter else { return }
        cancelTasks()
        timeRemaining = roundSeconds
        answers = [:]
        lockedInPlayerIds = []
        wasTimerCut = false
        roundAnswers = []
        activeVote = nil
        let lockWindow = max(Self.lockInCutSeconds + 1, roundSeconds / 5)...max(Self.lockInCutSeconds + 2, roundSeconds * 4 / 5)
        botLockInMarks = Dictionary(uniqueKeysWithValues: players.filter { !$0.isLocal }.map {
            ($0.id, Int.random(in: lockWindow))
        })
        gameState = .playing
        startTimer()
    }

    func lockIn() {
        guard let localPlayer, gameState == .playing, !isLocalLockedIn else { return }
        sounds.play(.lockIn)
        lockIn(localPlayer.id)
    }

    private func lockIn(_ playerId: UUID) {
        guard !lockedInPlayerIds.contains(playerId) else { return }
        lockedInPlayerIds.insert(playerId)
        if lockedInPlayerIds.count >= Self.lockInsToCutTimer, timeRemaining > Self.lockInCutSeconds {
            wasTimerCut = true
            setTimeRemaining(Self.lockInCutSeconds)
        }
    }

    /// Every change to the clock goes through here so the countdown sounds stay in step.
    private func setTimeRemaining(_ seconds: Int) {
        timeRemaining = max(0, seconds)
        if (1...Self.countdownSeconds).contains(timeRemaining) {
            sounds.setMusicDucked(true)
            sounds.play(.tick)
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
                self.setTimeRemaining(self.timeRemaining - 1)
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
        sounds.play(.timeUp)
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
        reactions = []
        revealCategoryIndex = 0
        gameState = .reveal
        startCategoryReveal(after: .seconds(1.8))
    }

    // MARK: - Reveal

    /// Shows the current category's answers one at a time, then its points.
    private func startCategoryReveal(after delay: Duration = .seconds(0.6)) {
        revealTask?.cancel()
        revealedAnswerCount = 0
        isCategoryScored = false
        guard let category = revealCategory else { return }
        let total = answers(for: category.id).count

        revealTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.sounds.setMusicDucked(false)
            while let self, !Task.isCancelled, self.revealedAnswerCount < total {
                try? await Task.sleep(for: .seconds(0.9))
                // Hold the reveal while a veto vote is running.
                while self.activeVote != nil, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.25))
                }
                guard !Task.isCancelled else { return }
                self.revealedAnswerCount += 1
                self.sounds.play(.pop)
                self.maybeBotReaction()
            }
            try? await Task.sleep(for: .seconds(0.7))
            guard let self, !Task.isCancelled else { return }
            self.isCategoryScored = true
            if self.answers(for: category.id).contains(where: { $0.points == Self.pointsOriginal }) {
                self.sounds.play(.sparkle)
            }
        }
    }

    /// Host only. Moves to the next category, then to the round scores.
    func nextCategory(by playerId: UUID) {
        guard isHost(playerId), gameState == .reveal, isCategoryScored, activeVote == nil,
              revealCategoryIndex < categories.count else { return }
        revealCategoryIndex += 1
        if revealCategory != nil {
            startCategoryReveal()
        } else {
            revealTask?.cancel()
        }
    }

    // MARK: - Reactions

    func react(_ emoji: String) {
        guard let localPlayer else { return }
        addReaction(emoji, from: localPlayer.name)
    }

    private func maybeBotReaction() {
        guard Double.random(in: 0..<1) < 0.4,
              let bot = players.filter({ !$0.isLocal }).randomElement(),
              let emoji = Self.reactionEmoji.randomElement() else { return }
        addReaction(emoji, from: bot.name)
    }

    private func addReaction(_ emoji: String, from name: String) {
        let reaction = Reaction(emoji: emoji, playerName: name, lane: Double.random(in: 0.12...0.88))
        reactions.append(reaction)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            self?.reactions.removeAll { $0.id == reaction.id }
        }
    }

    // MARK: - Veto and scoring

    /// Blank or rejected answers score 0. Otherwise: unique +10, exactly two the same +5, three or more 0.
    private func scoreRound() {
        var matches: [String: Int] = [:]
        for answer in roundAnswers where !answer.isBlank && answer.verdict == .accepted {
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
            && answer.playerId != localPlayer?.id && isRevealed(answer)
    }

    /// Starts a vote among everyone except the answer's author.
    func veto(_ answerId: UUID) {
        guard let answer = answer(answerId), canVeto(answer) else { return }
        let voters = players.filter { $0.id != answer.playerId }.map(\.id)
        activeVote = VetoVote(answerId: answerId, voterIds: voters)
        sounds.play(.veto)

        // Simulated players vote over the next couple of seconds.
        let bots = players.filter { !$0.isLocal && voters.contains($0.id) }.map(\.id)
        voteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
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
        guard isHost(playerId), isShowingRoundScores else { return }
        cancelTasks()
        activeVote = nil
        for index in players.indices {
            players[index].score += roundPoints(for: players[index].id)
        }
        roundAnswers = []
        reactions = []
        if isLastRound {
            gameState = .finalResults
            sounds.play(.sparkle)
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
        for task in [timerTask, shuffleTask, adTask, voteTask, revealTask] { task?.cancel() }
        timerTask = nil
        shuffleTask = nil
        adTask = nil
        voteTask = nil
        revealTask = nil
        sounds.setMusicDucked(false)
    }

    private func resetMatch() {
        cancelTasks()
        currentRound = 0
        currentLetter = "?"
        hasChosenLetter = false
        isShuffling = false
        isShowingAd = false
        timeRemaining = roundSeconds
        answers = [:]
        lockedInPlayerIds = []
        wasTimerCut = false
        roundAnswers = []
        activeVote = nil
        revealCategoryIndex = 0
        revealedAnswerCount = 0
        isCategoryScored = false
        reactions = []
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

// MARK: - Shuffle demo

#if DEBUG
extension GameViewModel {
    /// Debug only: jumps straight to Final results with set scores. Launch with `-DrawDemo` to see a draw.
    func showFinalResultsDemo(draw: Bool) {
        startNewGame()
        let totals = draw ? [140, 140, 95, 120] : [140, 125, 95, 120]
        for (index, total) in totals.enumerated() where players.indices.contains(index) {
            players[index].score = total
        }
        gameState = .finalResults
    }

    /// Debug only: shuffles over and over so the animation can be watched on repeat.
    /// Launch with `-ShuffleDemo`, or use the "Shuffle on repeat" preview.
    func runShuffleDemo() {
        startNewGame()
        guard let host = hostPlayer else { return }
        startGame(by: host.id)
        shuffleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.gameState == .choosingLetter else { return }
                self.currentLetter = "?"
                self.hasChosenLetter = false
                try? await Task.sleep(for: .seconds(0.9))
                self.runShuffle()
                // runShuffle replaces shuffleTask, so this loop keeps its own timing.
                try? await Task.sleep(for: .seconds(6.5))
            }
        }
    }
}
#endif

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
            viewModel.revealCategoryIndex = viewModel.categories.count
            viewModel.nextRound(by: host.id)
            viewModel.gameState = .finalResults
        }
        return viewModel
    }
}
