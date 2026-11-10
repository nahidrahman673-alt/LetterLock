//
//  GameModels.swift
//  LetterLock
//

import Foundation

enum GameState: Equatable {
    case home
    case lobby
    case playing
    case reveal
}

struct Category: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    static let defaults: [Category] = [
        "Animal",
        "Country",
        "Food",
        "Movie/TV",
        "Brand",
        "Name",
        "Sport",
        "Object",
        "Occupation",
        "City",
    ].map { Category(name: $0) }
}

struct Player: Identifiable, Hashable {
    let id: UUID
    var name: String
    var score: Int
    var isHost: Bool
    var isReady: Bool

    init(
        id: UUID = UUID(),
        name: String,
        score: Int = 0,
        isHost: Bool = false,
        isReady: Bool = false
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.isHost = isHost
        self.isReady = isReady
    }
}

struct RoundAnswer: Identifiable, Hashable {
    var categoryId: UUID
    var text: String
    var points: Int
    var isVetoed: Bool

    var id: UUID { categoryId }

    init(categoryId: UUID, text: String, points: Int = 0, isVetoed: Bool = false) {
        self.categoryId = categoryId
        self.text = text
        self.points = points
        self.isVetoed = isVetoed
    }
}
