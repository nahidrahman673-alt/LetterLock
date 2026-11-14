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
    /// 1 round was added after playtesting, for quick games.
    static let roundOptions = [1, 3, 5]
    static let defaultRounds = 5
    /// First option is the default.
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

    /// Sudden Death: seconds to answer, and how many tries before the tied players share the win.
    static let suddenDeathSeconds = 10
    static let suddenDeathTries = 3
    static let suddenDeathIntroSeconds = 3.0
    /// Sudden Death never uses these: too few fair answers for a 10-second race.
    static let suddenDeathLetters = letterPool.filter { !["Q", "X", "Z"].contains($0) }
    /// An answer last typed in this close to 0:00 (and not locked in) is tagged "Cut off".
    static let cutOffWindow = 2.0

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
    var totalRounds = GameViewModel.defaultRounds
    var roundSeconds = GameViewModel.timerOptions[0]
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
    /// Turns on a moment after the points show. Skip becomes Next Category in the same spot, so this
    /// stops a double tap (or a tap just as the reveal ends) from jumping past the chance to Veto.
    private(set) var canMoveOnFromCategory = false
    private(set) var reactions: [Reaction] = []

    // Sudden Death: only the tied players answer; everyone else judges.
    private(set) var suddenDeathPlayerIds: [UUID] = []
    private(set) var suddenDeathTry = 0
    private(set) var suddenDeathPhase = SuddenDeathPhase.intro
    private(set) var suddenDeathCategory: Category?
    var suddenDeathAnswer = ""
    private(set) var suddenDeathAnswers: [RoundAnswer] = []
    /// Seconds from the question appearing to locking in, per player.
    private(set) var suddenDeathTimes: [UUID: Double] = [:]
    private(set) var canMoveOnFromSuddenDeath = false
    private(set) var suddenDeathWinnerId: UUID?
    /// True when 3 tries all ended with no winner, so the tied players share first place.
    private(set) var isSharedWin = false
    /// "Same answer?" pairs that have already been voted on, so the same pair can't be flagged twice.
    private(set) var votedMatchPairs: Set<String> = []
    /// When each of this phone's answers was last typed in, to spot answers cut off at 0:00.
    @ObservationIgnored private var answerEditedAt: [UUID: Date] = [:]
    @ObservationIgnored private var suddenDeathStart: Date?
    @ObservationIgnored private var suddenDeathTexts: [UUID: String] = [:]
    @ObservationIgnored private var botSuddenDeathPlans: [UUID: (seconds: Double, text: String)] = [:]

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

    /// Players sorted by total score, including the round being revealed. A Sudden Death winner
    /// goes above the players they were tied with.
    var standings: [(player: Player, total: Int)] {
        let winnerId = suddenDeathWinnerId
        return players
            .map { ($0, $0.score + (gameState == .reveal ? roundPoints(for: $0.id) : 0)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : ($0.0.id == winnerId && $1.0.id != winnerId) }
    }

    /// Who won: the Sudden Death winner, or everyone on the top total if they share the win.
    var champions: [Player] {
        if let winnerId = suddenDeathWinnerId, let winner = player(winnerId) { return [winner] }
        guard let top = standings.first?.total else { return [] }
        return standings.filter { $0.total == top }.map(\.player)
    }

    /// Place on Final results. Equal totals share a place (1, 1, 3), except that a Sudden Death
    /// winner takes 1st and the players they beat take 2nd.
    func finalPlace(for playerId: UUID, total: Int) -> Int {
        var place = 1 + standings.filter { $0.total > total }.count
        if let winnerId = suddenDeathWinnerId, winnerId != playerId, player(winnerId)?.score == total {
            place += 1
        }
        return place
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

    func answer(_ id: UUID) -> RoundAnswer? {
        roundAnswers.first { $0.id == id } ?? suddenDeathAnswers.first { $0.id == id }
    }

    func categoryName(for id: UUID) -> String {
        categories.first { $0.id == id }?.name ?? ""
    }

    // MARK: - Player name

    private static let playerNameKey = "playerName"
    static let playerNameLimit = 16

    /// The name this phone's player goes by. Asked once, then saved on the phone. Empty until set.
    private(set) var playerName = UserDefaults.standard.string(forKey: GameViewModel.playerNameKey) ?? ""

    var hasPlayerName: Bool { !playerName.isEmpty }

    /// Saves the name (trimmed, up to the limit) and renames this player if they're already in a room.
    func setPlayerName(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.playerNameLimit))
        guard !trimmed.isEmpty else { return }
        playerName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.playerNameKey)
        if let index = players.firstIndex(where: \.isLocal) {
            players[index].name = trimmed
        }
    }

    // MARK: - Home and lobby

    func startNewGame() {
        resetMatch()
        roomCode = Self.makeRoomCode()
        players = mockPlayers(localPlayerIsHost: true)
        gameState = .lobby
    }

    func joinGame(code: String) {
        guard Self.isValidRoomCode(code) else { return }
        resetMatch()
        roomCode = Self.normalizedRoomCode(code)
        players = mockPlayers(localPlayerIsHost: false)
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
        answerEditedAt = [:]
        votedMatchPairs = []
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

    func setAnswer(_ text: String, for categoryId: UUID) {
        guard !isInputFrozen else { return }
        answers[categoryId] = text
        answerEditedAt[categoryId] = .now
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
        let endedAt = Date.now
        let localWasLockedIn = isLocalLockedIn
        roundAnswers = players.flatMap { player in
            categories.map { category in
                let text = player.isLocal
                    ? answers[category.id, default: ""]
                    : MockAnswerBank.answer(for: category.name, letter: currentLetter)
                var answer = RoundAnswer(
                    playerId: player.id,
                    categoryId: category.id,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                answer.hasWrongLetter = !answer.isBlank && !LetterRule.fits(answer.text, letter: currentLetter)
                // Still being typed in the last couple of seconds, and never locked in: probably cut off.
                if player.isLocal, !localWasLockedIn, !answer.isBlank,
                   let editedAt = answerEditedAt[category.id], endedAt.timeIntervalSince(editedAt) < Self.cutOffWindow {
                    answer.wasCutOff = true
                }
                return answer
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
    private func startCategoryReveal(after delay: Duration = .seconds(0.4)) {
        revealTask?.cancel()
        revealedAnswerCount = 0
        isCategoryScored = false
        canMoveOnFromCategory = false
        guard let category = revealCategory else { return }
        let total = answers(for: category.id).count

        revealTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.sounds.setMusicDucked(false)
            while let self, !Task.isCancelled, self.revealedAnswerCount < total {
                // Sped up after playtesting (was 0.9s); the host can also Skip.
                try? await Task.sleep(for: .seconds(0.5))
                // Hold the reveal while a veto vote is running.
                while self.activeVote != nil, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.25))
                }
                guard !Task.isCancelled else { return }
                self.revealedAnswerCount += 1
                self.sounds.play(.pop)
                self.maybeBotReaction()
                self.maybeBotVetoCutOff(self.answers(for: category.id)[self.revealedAnswerCount - 1])
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard let self, !Task.isCancelled else { return }
            self.showCategoryPoints()
        }
    }

    private func showCategoryPoints() {
        guard let category = revealCategory else { return }
        isCategoryScored = true
        if answers(for: category.id).contains(where: { $0.points == Self.pointsOriginal }) {
            sounds.play(.sparkle)
        }
        let index = revealCategoryIndex
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.revealCategoryIndex == index, self.isCategoryScored else { return }
            self.canMoveOnFromCategory = true
        }
    }

    /// Host only. Shows every answer in this category at once, with its points. Players can still
    /// veto afterwards, so skipping never takes that chance away.
    func skipCategoryReveal(by playerId: UUID) {
        guard isHost(playerId), gameState == .reveal, !isCategoryScored, activeVote == nil,
              let category = revealCategory else { return }
        revealTask?.cancel()
        sounds.setMusicDucked(false)
        revealedAnswerCount = answers(for: category.id).count
        sounds.play(.pop)
        showCategoryPoints()
    }

    /// Host only. Moves to the next category, then to the round scores.
    func nextCategory(by playerId: UUID) {
        guard isHost(playerId), gameState == .reveal, canMoveOnFromCategory, activeVote == nil,
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

    /// Blank, wrong-letter or rejected answers score 0. Otherwise: unique +10, exactly two the same +5, three or more 0.
    private func scoreRound() {
        var matches: [String: Int] = [:]
        for answer in roundAnswers where answer.canScore {
            matches["\(answer.categoryId)|\(answer.scoringKey)", default: 0] += 1
        }
        for index in roundAnswers.indices {
            let answer = roundAnswers[index]
            guard answer.canScore else {
                roundAnswers[index].points = 0
                continue
            }
            switch matches["\(answer.categoryId)|\(answer.scoringKey)", default: 1] {
            case 1: roundAnswers[index].points = Self.pointsOriginal
            case 2: roundAnswers[index].points = Self.pointsShared
            default: roundAnswers[index].points = 0
            }
        }
    }

    func canVeto(_ answer: RoundAnswer) -> Bool {
        guard activeVote == nil, answer.canScore, !answer.wasVoted, answer.playerId != localPlayer?.id else { return false }
        switch gameState {
        case .reveal: return isRevealed(answer)
        // In Sudden Death only the players who are waiting (the judges) can Veto.
        case .suddenDeath: return suddenDeathPhase == .result && !isLocalInSuddenDeath
        default: return false
        }
    }

    /// Starts a vote among everyone except the answer's author. In Sudden Death only the judges vote.
    func veto(_ answerId: UUID) {
        guard let answer = answer(answerId), canVeto(answer) else { return }
        startVeto(of: answer, acceptChance: 0.55)
    }

    private func startVeto(of answer: RoundAnswer, acceptChance: Double) {
        let voters = players
            .filter { $0.id != answer.playerId }
            .filter { gameState != .suddenDeath || !suddenDeathPlayerIds.contains($0.id) }
            .map(\.id)
        activeVote = VetoVote(answerId: answer.id, voterIds: voters)
        sounds.play(.veto)
        runBotBallots(voters, acceptChance: acceptChance)
    }

    /// Simulated players vote over the next couple of seconds.
    private func runBotBallots(_ voters: [UUID], acceptChance: Double) {
        let bots = players.filter { !$0.isLocal && voters.contains($0.id) }.map(\.id)
        voteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            for id in bots.shuffled() {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 400...1100)))
                guard let self, !Task.isCancelled else { return }
                self.recordBallot(from: id, accept: Double.random(in: 0..<1) < acceptChance)
            }
        }
    }

    /// Prototype only: a simulated player often vetoes an answer that was cut off at 0:00,
    /// the way friends would, so the "Cut off" tag can be seen doing its job on one phone.
    private func maybeBotVetoCutOff(_ answer: RoundAnswer) {
        guard answer.wasCutOff, answer.canScore, !answer.wasVoted, activeVote == nil,
              Double.random(in: 0..<1) < 0.7 else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.6))
            guard let self, self.gameState == .reveal, self.activeVote == nil,
                  let current = self.answer(answer.id), !current.wasVoted else { return }
            self.startVeto(of: current, acceptChance: 0.35)
        }
    }

    // MARK: - Same answer?

    static func matchPairKey(_ a: UUID, _ b: UUID) -> String {
        [a.uuidString, b.uuidString].sorted().joined(separator: "|")
    }

    /// Two answers in the same category that could be voted the same: both still scoring,
    /// not already a match, and not voted on before. Only once the category's points are showing.
    func canFlagMatch(_ a: RoundAnswer, _ b: RoundAnswer) -> Bool {
        gameState == .reveal && isCategoryScored && activeVote == nil
            && a.categoryId == revealCategory?.id && a.categoryId == b.categoryId && a.id != b.id
            && a.canScore && b.canScore && a.scoringKey != b.scoringKey
            && !votedMatchPairs.contains(Self.matchPairKey(a.id, b.id))
    }

    /// Pairs the app thinks look or sound alike, for the "Same answer?" suggestion.
    func suggestedMatches(in categoryId: UUID) -> [(RoundAnswer, RoundAnswer)] {
        let list = answers(for: categoryId).filter(\.canScore)
        var pairs: [(RoundAnswer, RoundAnswer)] = []
        for i in list.indices {
            for j in list.indices where j > i && canFlagMatch(list[i], list[j]) {
                if AnswerSimilarity.looksAlike(list[i].text, list[j].text) { pairs.append((list[i], list[j])) }
            }
        }
        return pairs
    }

    /// Anyone can ask. Everyone except the two authors votes; more Same than Different makes them a match.
    func flagMatch(_ firstId: UUID, _ secondId: UUID) {
        guard let first = answer(firstId), let second = answer(secondId), canFlagMatch(first, second) else { return }
        var voters = players.filter { $0.id != first.playerId && $0.id != second.playerId }.map(\.id)
        if voters.isEmpty { voters = players.map(\.id) }   // Two-player game: both authors vote.
        activeVote = VetoVote(answerId: firstId, voterIds: voters, matchAnswerId: secondId)
        sounds.play(.veto)
        runBotBallots(voters, acceptChance: AnswerSimilarity.looksAlike(first.text, second.text) ? 0.75 : 0.35)
    }

    /// Every answer that already matches either one ends up in the same group.
    private func mergeAnswers(_ firstId: UUID, _ secondId: UUID) {
        guard let first = answer(firstId), let second = answer(secondId) else { return }
        let target = first.scoringKey
        let keys: Set<String> = [first.scoringKey, second.scoringKey]
        for index in roundAnswers.indices
        where roundAnswers[index].categoryId == first.categoryId && keys.contains(roundAnswers[index].scoringKey) {
            roundAnswers[index].mergedKey = target
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
        guard vote.isComplete else { return }
        if let otherId = vote.matchAnswerId {
            votedMatchPairs.insert(Self.matchPairKey(vote.answerId, otherId))
            if vote.isSameAnswer { mergeAnswers(vote.answerId, otherId) }
            scoreRound()
        } else if let index = roundAnswers.firstIndex(where: { $0.id == vote.answerId }) {
            roundAnswers[index].verdict = vote.verdict
            roundAnswers[index].wasVoted = true
            scoreRound()
        } else if let index = suddenDeathAnswers.firstIndex(where: { $0.id == vote.answerId }) {
            suddenDeathAnswers[index].verdict = vote.verdict
            suddenDeathAnswers[index].wasVoted = true
        }
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
            let leaders = tiedLeaders()
            if leaders.count > 1 {
                startSuddenDeath(leaders)
            } else {
                gameState = .finalResults
                sounds.play(.sparkle)
            }
        } else {
            currentRound += 1
            beginLetterChoice()
        }
    }

    // MARK: - Sudden Death

    var isLocalInSuddenDeath: Bool {
        guard let localPlayer else { return false }
        return suddenDeathPlayerIds.contains(localPlayer.id)
    }

    var suddenDeathPlayers: [Player] { suddenDeathPlayerIds.compactMap(player) }

    var isLocalSuddenDeathLockedIn: Bool {
        guard let localPlayer else { return false }
        return suddenDeathTexts[localPlayer.id] != nil
    }

    /// Seconds to lock in. Anyone who never locked in is timed at the full 10 seconds.
    func suddenDeathSeconds(for playerId: UUID) -> Double {
        suddenDeathTimes[playerId] ?? Double(Self.suddenDeathSeconds)
    }

    /// Answers fastest first.
    var suddenDeathResults: [RoundAnswer] {
        suddenDeathAnswers.sorted { suddenDeathSeconds(for: $0.playerId) < suddenDeathSeconds(for: $1.playerId) }
    }

    /// The fastest answer that has the right letter, wasn't vetoed and nobody else gave. Nil if there isn't one.
    var suddenDeathLeaderId: UUID? {
        let valid = suddenDeathAnswers.filter(\.canScore)
        let counts = Dictionary(grouping: valid, by: \.matchKey).mapValues(\.count)
        return valid
            .filter { counts[$0.matchKey] == 1 }
            .min { suddenDeathSeconds(for: $0.playerId) < suddenDeathSeconds(for: $1.playerId) }?
            .playerId
    }

    func suddenDeathOutcome(for answer: RoundAnswer) -> SuddenDeathOutcome {
        if answer.isBlank { return .blank }
        if answer.hasWrongLetter { return .wrongLetter }
        if answer.verdict == .rejected { return .rejected }
        let sameCount = suddenDeathAnswers.filter { $0.canScore && $0.matchKey == answer.matchKey }.count
        if sameCount > 1 { return .sameAnswer }
        return answer.playerId == suddenDeathLeaderId ? .winner : .slower
    }

    var isLastSuddenDeathTry: Bool { suddenDeathTry >= Self.suddenDeathTries }

    /// Hundredths of a second, like a race: "3.42s".
    static func formatSeconds(_ seconds: Double) -> String {
        String(format: "%.2fs", seconds)
    }

    private func tiedLeaders() -> [UUID] {
        guard let top = players.map(\.score).max() else { return [] }
        return players.filter { $0.score == top }.map(\.id)
    }

    private func startSuddenDeath(_ playerIds: [UUID]) {
        suddenDeathPlayerIds = playerIds
        suddenDeathTry = 0
        suddenDeathWinnerId = nil
        isSharedWin = false
        gameState = .suddenDeath
        beginSuddenDeathTry()
    }

    /// A new category and letter each try, picked by the app (no shuffle).
    private func beginSuddenDeathTry() {
        cancelTasks()
        suddenDeathTry += 1
        suddenDeathPhase = .intro
        suddenDeathCategory = categories.randomElement()
        var letter = Self.suddenDeathLetters.randomElement() ?? "A"
        while letter == currentLetter { letter = Self.suddenDeathLetters.randomElement() ?? "A" }
        currentLetter = letter
        suddenDeathAnswer = ""
        suddenDeathAnswers = []
        suddenDeathTimes = [:]
        suddenDeathTexts = [:]
        lockedInPlayerIds = []
        activeVote = nil
        canMoveOnFromSuddenDeath = false
        timeRemaining = Self.suddenDeathSeconds
        sounds.play(.veto)

        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.suddenDeathIntroSeconds))
            guard let self, !Task.isCancelled else { return }
            self.startSuddenDeathAnswering()
        }
    }

    private func startSuddenDeathAnswering() {
        guard let category = suddenDeathCategory else { return }
        suddenDeathPhase = .answering
        let start = Date.now
        suddenDeathStart = start
        // Simulated tied players answer somewhere between 2 and 9.5 seconds in.
        botSuddenDeathPlans = Dictionary(uniqueKeysWithValues: suddenDeathPlayers.filter { !$0.isLocal }.map {
            ($0.id, (seconds: Double.random(in: 2...9.5), text: MockAnswerBank.answer(for: category.name, letter: currentLetter)))
        })
        sounds.play(.land)

        timerTask = Task { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return
                }
                guard let self else { return }
                let elapsed = Date.now.timeIntervalSince(start)
                for (id, plan) in self.botSuddenDeathPlans where elapsed >= plan.seconds {
                    self.recordSuddenDeathLockIn(id, text: plan.text, seconds: plan.seconds)
                }
                let secondsLeft = max(0, Self.suddenDeathSeconds - Int(elapsed))
                if secondsLeft != self.timeRemaining { self.setTimeRemaining(secondsLeft) }
                let everyoneIn = self.suddenDeathPlayerIds.allSatisfy { self.suddenDeathTexts[$0] != nil }
                if everyoneIn || elapsed >= Double(Self.suddenDeathSeconds) {
                    self.endSuddenDeathTry()
                    return
                }
            }
        }
    }

    /// No "are you sure?" here: it's a race.
    func lockInSuddenDeath() {
        guard gameState == .suddenDeath, suddenDeathPhase == .answering, let localPlayer, let suddenDeathStart,
              isLocalInSuddenDeath, !isLocalSuddenDeathLockedIn else { return }
        sounds.play(.lockIn)
        recordSuddenDeathLockIn(localPlayer.id, text: suddenDeathAnswer, seconds: Date.now.timeIntervalSince(suddenDeathStart))
    }

    private func recordSuddenDeathLockIn(_ playerId: UUID, text: String, seconds: Double) {
        guard suddenDeathTexts[playerId] == nil else { return }
        suddenDeathTexts[playerId] = text
        suddenDeathTimes[playerId] = min(seconds, Double(Self.suddenDeathSeconds))
        lockedInPlayerIds.insert(playerId)
    }

    private func endSuddenDeathTry() {
        guard gameState == .suddenDeath, suddenDeathPhase == .answering, let category = suddenDeathCategory else { return }
        timerTask?.cancel()
        timerTask = nil
        sounds.setMusicDucked(false)
        sounds.play(.timeUp)
        // Whatever the local player had typed at 0:00 counts, timed at the full 10 seconds.
        if let localPlayer, isLocalInSuddenDeath, suddenDeathTexts[localPlayer.id] == nil {
            suddenDeathTexts[localPlayer.id] = suddenDeathAnswer
        }
        suddenDeathAnswers = suddenDeathPlayerIds.map { id in
            var answer = RoundAnswer(
                playerId: id,
                categoryId: category.id,
                text: suddenDeathTexts[id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            )
            answer.hasWrongLetter = !answer.isBlank && !LetterRule.fits(answer.text, letter: currentLetter)
            return answer
        }
        suddenDeathPhase = .result
        let attempt = suddenDeathTry
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.suddenDeathTry == attempt, self.suddenDeathPhase == .result else { return }
            self.canMoveOnFromSuddenDeath = true
        }
    }

    /// Host only. Crowns the winner, starts another try, or (after the last try) shares the win.
    func finishSuddenDeathTry(by playerId: UUID) {
        guard isHost(playerId), gameState == .suddenDeath, suddenDeathPhase == .result,
              canMoveOnFromSuddenDeath, activeVote == nil else { return }
        if let winner = suddenDeathLeaderId {
            suddenDeathWinnerId = winner
        } else if !isLastSuddenDeathTry {
            beginSuddenDeathTry()
            return
        } else {
            isSharedWin = true
        }
        cancelTasks()
        gameState = .finalResults
        sounds.play(.sparkle)
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
        canMoveOnFromCategory = false
        reactions = []
        suddenDeathPlayerIds = []
        suddenDeathTry = 0
        suddenDeathPhase = .intro
        suddenDeathCategory = nil
        suddenDeathAnswer = ""
        suddenDeathAnswers = []
        suddenDeathTimes = [:]
        suddenDeathTexts = [:]
        canMoveOnFromSuddenDeath = false
        suddenDeathWinnerId = nil
        isSharedWin = false
        for index in players.indices { players[index].score = 0 }
    }

    private static func makeRoomCode() -> String {
        (0..<roomCodeLength).compactMap { _ in roomCodeCharacters.randomElement() }.joined()
    }

    private func mockPlayers(localPlayerIsHost: Bool) -> [Player] {
        [
            Player(name: hasPlayerName ? playerName : "You", isHost: localPlayerIsHost, isReady: true, isLocal: true),
            Player(name: "Sam", isHost: !localPlayerIsHost, isReady: true),
            Player(name: "Priya", isReady: true),
            Player(name: "Leo", isReady: true),
        ]
    }
}

// MARK: - Shuffle demo

#if DEBUG
extension GameViewModel {
    /// Debug only: jumps to the end of a game with set scores. Launch with `-DrawDemo` to see a tie
    /// go to Sudden Death (you against Sam).
    func showFinalResultsDemo(draw: Bool) {
        startNewGame()
        let totals = draw ? [140, 140, 95, 120] : [140, 125, 95, 120]
        for (index, total) in totals.enumerated() where players.indices.contains(index) {
            players[index].score = total
        }
        let leaders = tiedLeaders()
        if leaders.count > 1 {
            startSuddenDeath(leaders)
        } else {
            gameState = .finalResults
        }
    }

    /// Debug only: from the lobby, skips the rounds and ties you with the next player on 140,
    /// so Sudden Death starts straight away. Everyone else is a judge.
    func startSuddenDeathDemo() {
        guard gameState == .lobby, canStartGame, let localPlayer,
              let rival = players.first(where: { !$0.isLocal }) else { return }
        resetMatch()
        currentRound = totalRounds
        for index in players.indices {
            let id = players[index].id
            players[index].score = (id == localPlayer.id || id == rival.id) ? 140 : Int.random(in: 6...12) * 10
        }
        startSuddenDeath([localPlayer.id, rival.id])
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
