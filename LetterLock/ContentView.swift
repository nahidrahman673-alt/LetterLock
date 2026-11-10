//
//  ContentView.swift
//  LetterLock
//
//  Created by Nahid Rahman on 10/11/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        Group {
            switch viewModel.gameState {
            case .home:
                HomeView(viewModel: viewModel)
            case .lobby:
                LobbyView(viewModel: viewModel)
            case .playing:
                GameBoardView(viewModel: viewModel)
            case .reveal:
                RevealView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
