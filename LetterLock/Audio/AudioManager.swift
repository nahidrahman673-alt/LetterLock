//
//  AudioManager.swift
//  LetterLock
//

import AVFoundation
import Observation

enum SoundEffect: String, CaseIterable {
    case tick
    /// The 0:00 sound: Dark Gong, a low strike on D tuned to sit with Midnight Pulse.
    case timeUp = "end_darkgong"
    case veto
    case sparkle
    case pop
    case clack
    case land
    case lockIn = "lock"

    fileprivate var volume: Float {
        switch self {
        case .clack: 0.35
        case .pop: 0.5
        case .timeUp: 0.65
        case .tick: 0.8
        default: 0.9
        }
    }
}

/// What the game logic needs from audio. Previews use `SilentSoundPlayer`.
protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect)
    /// Lowers the music so the countdown ticks stand out.
    func setMusicDucked(_ ducked: Bool)
}

final class SilentSoundPlayer: SoundPlaying {
    func play(_ effect: SoundEffect) {}
    func setMusicDucked(_ ducked: Bool) {}
}

/// Plays the background loop (Midnight Pulse) and sound effects. The mute toggle silences both and is remembered.
@Observable
final class AudioManager: SoundPlaying {
    private static let mutedKey = "audioMuted"
    private static let musicOffKey = "musicOff"
    private static let musicFile = "music_midnight"
    private static let musicVolume: Float = 0.5
    private static let duckedMusicVolume: Float = 0.17
    /// A few players per effect so rapid repeats (shuffle clacks, ticks) can overlap.
    private static let voicesPerEffect = 3

    private(set) var isMuted: Bool
    /// Background music only. Sound effects still play when this is off; the mute button silences both.
    private(set) var isMusicOn: Bool

    @ObservationIgnored private var music: AVAudioPlayer?
    @ObservationIgnored private var effects: [SoundEffect: [AVAudioPlayer]] = [:]
    @ObservationIgnored private var nextVoice: [SoundEffect: Int] = [:]
    @ObservationIgnored private var isDucked = false

    init() {
        isMuted = UserDefaults.standard.bool(forKey: Self.mutedKey)
        isMusicOn = !UserDefaults.standard.bool(forKey: Self.musicOffKey)

        // Ambient mixes with other apps' audio and follows the ring/silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        music = Self.makeMusicPlayer()
        for effect in SoundEffect.allCases {
            guard let url = Self.url(for: effect.rawValue) else { continue }
            effects[effect] = (0..<Self.voicesPerEffect).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.volume = effect.volume
                player?.prepareToPlay()
                return player
            }
        }
    }

    func startMusic() {
        guard !isMuted, isMusicOn, music?.isPlaying == false else { return }
        music?.play()
    }

    func setMusicOn(_ on: Bool) {
        guard on != isMusicOn else { return }
        isMusicOn = on
        UserDefaults.standard.set(!on, forKey: Self.musicOffKey)
        if on { startMusic() } else { music?.pause() }
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: Self.mutedKey)
        if isMuted {
            music?.pause()
            effects.values.joined().forEach { $0.stop() }
        } else {
            startMusic()
        }
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted, let voices = effects[effect], !voices.isEmpty else { return }
        let index = nextVoice[effect, default: 0]
        nextVoice[effect] = (index + 1) % voices.count
        let player = voices[index]
        player.currentTime = 0
        player.play()
    }

    func setMusicDucked(_ ducked: Bool) {
        guard ducked != isDucked else { return }
        isDucked = ducked
        music?.setVolume(ducked ? Self.duckedMusicVolume : Self.musicVolume, fadeDuration: 0.4)
    }

    private static func makeMusicPlayer() -> AVAudioPlayer? {
        guard let url = url(for: musicFile), let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.numberOfLoops = -1
        player.volume = musicVolume
        player.prepareToPlay()
        return player
    }

    private static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio")
    }
}
