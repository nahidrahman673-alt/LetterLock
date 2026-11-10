//
//  GameViewModel.swift
//  LetterLock
//

import Foundation
import Observation

@Observable
final class GameViewModel {
    static let roundDuration = 60
    static let roomCodeLength = 4

    /// A–Z without Q, X, Y and Z.
    private static let letterPool = Array("ABCDEFGHIJKLMNOPRSTUVW").map(String.init)
    private static let roomCodeCharacters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ").map(String.init)

    var gameState: GameState = .home
    var currentLetter = "A"
    var timeRemaining = GameViewModel.roundDuration
    var categories = Category.defaults
    var answers: [UUID: String] = [:]

    private(set) var isInputFrozen = false
    private(set) var roundAnswers: [RoundAnswer] = []
    private(set) var roomCode = ""
    private(set) var players: [Player] = []

    @ObservationIgnored private var timerTask: Task<Void, Never>?

    // MARK: - Game flow

    func startNewGame() {
        roomCode = (0..<Self.roomCodeLength)
            .compactMap { _ in Self.roomCodeCharacters.randomElement() }
            .joined()
        players = Self.mockPlayers(localPlayerIsHost: true)
        gameState = .lobby
    }

    func joinGame(code: String) {
        guard Self.isValidRoomCode(code) else { return }
        roomCode = Self.normalizedRoomCode(code)
        players = Self.mockPlayers(localPlayerIsHost: false)
        gameState = .lobby
    }

    func startRound() {
        timerTask?.cancel()
        currentLetter = Self.letterPool.randomElement() ?? "A"
        timeRemaining = Self.roundDuration
        answers = [:]
        roundAnswers = []
        isInputFrozen = false
        gameState = .playing
        startTimer()
    }

    /// Freezes input, snapshots the answers and moves to the reveal. Also runs when the timer ends.
    func stopTheBus() {
        guard gameState == .playing, !isInputFrozen else { return }
        isInputFrozen = true
        timerTask?.cancel()
        timerTask = nil
        roundAnswers = categories.map { category in
            RoundAnswer(
                categoryId: category.id,
                text: (answers[category.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        gameState = .reveal
    }

    func resetToHome() {
        timerTask?.cancel()
        timerTask = nil
        timeRemaining = Self.roundDuration
        answers = [:]
        roundAnswers = []
        isInputFrozen = false
        roomCode = ""
        players = []
        gameState = .home
    }

    // MARK: - Helpers

    func categoryName(for id: UUID) -> String {
        categories.first { $0.id == id }?.name ?? ""
    }

    static func normalizedRoomCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValidRoomCode(_ code: String) -> Bool {
        let normalized = normalizedRoomCode(code)
        return normalized.count == roomCodeLength && normalized.allSatisfy { $0.isLetter || $0.isNumber }
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
                if self.timeRemaining <= 0 {
                    self.stopTheBus()
                    return
                }
            }
        }
    }

    private static func mockPlayers(localPlayerIsHost: Bool) -> [Player] {
        [
            Player(name: "You", isHost: localPlayerIsHost, isReady: true),
            Player(name: "Sam", isHost: !localPlayerIsHost, isReady: true),
            Player(name: "Priya", isReady: true),
            Player(name: "Leo"),
        ]
    }
}

// MARK: - SwiftUI previews

extension GameViewModel {
    static func preview(_ state: GameState) -> GameViewModel {
        let viewModel = GameViewModel()
        guard state != .home else { return viewModel }

        viewModel.startNewGame()
        guard state != .lobby else { return viewModel }

        viewModel.startRound()
        if let first = viewModel.categories.first {
            viewModel.answers[first.id] = "\(viewModel.currentLetter)-animal"
        }
        if state == .reveal {
            viewModel.stopTheBus()
        }
        return viewModel
    }
}
