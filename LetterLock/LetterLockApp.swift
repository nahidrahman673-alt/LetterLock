//
//  LetterLockApp.swift
//  LetterLock
//
//  Created by Nahid Rahman on 10/11/2026.
//

import SwiftUI

@main
struct LetterLockApp: App {
    init() {
        // Read the city list in the background so the first reveal doesn't wait for it.
        Task.detached(priority: .utility) { WordList.preload() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
