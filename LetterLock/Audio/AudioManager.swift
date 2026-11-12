//
//  AudioManager.swift
//  LetterLock
//

import AVFoundation
import Observation

enum SoundEffect: String, CaseIterable {
    case tick
    /// The 0:00 sound. Plays whichever `EndSound` the player picked in the lobby.
    case timeUp
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
        case .tick: 0.8
        default: 0.9
        }
    }
}

/// Candidates for the end-of-round sound, chosen per phone in the lobby while we pick a final one.
/// The two finalists, both tuned to D minor to sit with the Midnight Pulse track.
enum EndSound: String, CaseIterable, Identifiable {
    case darkGong = "end_darkgong"
    case echoBell = "end_echobell"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .darkGong: "Dark Gong"
        case .echoBell: "Echo Bell"
        }
    }

    /// Evens out loudness between the two (measured on the generated files; the low gong nudged up).
    fileprivate var volume: Float {
        switch self {
        case .darkGong: 0.65
        case .echoBell: 0.55
        }
    }
}

/// Background music choices. All six are original placeholder synthwave/electronic loops.
enum MusicTrack: String, CaseIterable, Identifiable {
    /// Outrun synthwave: driving 16th bass, big snare, wide pads, soaring lead.
    case neon = "music_neon"
    /// Energetic electro: four-on-the-floor with pumping supersaw chords and a pluck riff.
    case laser = "music_laser"
    /// Dark retro-synth: minor key, gated arpeggio, deep bass.
    case midnight = "music_midnight"
    /// Sparkling arp-driven synthwave: a rippling two-octave saw arpeggio carries the track.
    case hyperlight = "music_hyperlight"
    /// High-energy electro: hard four-on-the-floor, octave-stab bass, racing lead.
    case velocity = "music_velocity"
    /// Funky synthwave: slap-style bass, off-beat chord stabs, singing lead.
    case afterglow = "music_afterglow"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neon: "Neon Drive"
        case .laser: "Laser Grid"
        case .midnight: "Midnight Pulse"
        case .hyperlight: "Hyperlight"
        case .velocity: "Velocity"
        case .afterglow: "Afterglow"
        }
    }

    /// Evens out loudness between the loops.
    fileprivate var volumeScale: Float {
        switch self {
        case .neon: 1.6
        case .laser: 1.45
        case .midnight: 1.45
        case .hyperlight: 1.45
        case .velocity: 1.6
        case .afterglow: 1.6
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

/// Plays the background loop and sound effects. The mute toggle silences both and is remembered.
@Observable
final class AudioManager: SoundPlaying {
    private static let mutedKey = "audioMuted"
    private static let trackKey = "musicTrack"
    private static let endSoundKey = "endSound"
    private static let musicOffKey = "musicOff"
    private static let musicVolume: Float = 0.35
    private static let duckedMusicVolume: Float = 0.12
    /// A few players per effect so rapid repeats (shuffle clacks, ticks) can overlap.
    private static let voicesPerEffect = 3

    private(set) var isMuted: Bool
    private(set) var track: MusicTrack
    private(set) var endSound: EndSound
    /// Background music only. Sound effects still play when this is off; the mute button silences both.
    private(set) var isMusicOn: Bool

    @ObservationIgnored private var music: AVAudioPlayer?
    @ObservationIgnored private var endPlayers: [EndSound: AVAudioPlayer] = [:]
    @ObservationIgnored private var effects: [SoundEffect: [AVAudioPlayer]] = [:]
    @ObservationIgnored private var nextVoice: [SoundEffect: Int] = [:]
    @ObservationIgnored private var isDucked = false

    init() {
        isMuted = UserDefaults.standard.bool(forKey: Self.mutedKey)
        track = UserDefaults.standard.string(forKey: Self.trackKey).flatMap(MusicTrack.init(rawValue:)) ?? .neon
        endSound = UserDefaults.standard.string(forKey: Self.endSoundKey).flatMap(EndSound.init(rawValue:)) ?? .darkGong
        isMusicOn = !UserDefaults.standard.bool(forKey: Self.musicOffKey)

        // Ambient mixes with other apps' audio and follows the ring/silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)

        music = Self.makeMusicPlayer(for: track)
        for effect in SoundEffect.allCases {
            guard let url = Self.url(for: effect.rawValue) else { continue }
            effects[effect] = (0..<Self.voicesPerEffect).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.volume = effect.volume
                player?.prepareToPlay()
                return player
            }
        }
        for sound in EndSound.allCases {
            guard let url = Self.url(for: sound.rawValue), let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = sound.volume
            player.prepareToPlay()
            endPlayers[sound] = player
        }
    }

    /// Picks the end-of-round sound and plays it once so it can be compared straight away.
    func selectEndSound(_ newSound: EndSound) {
        endSound = newSound
        UserDefaults.standard.set(newSound.rawValue, forKey: Self.endSoundKey)
        play(.timeUp)
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

    /// Swaps the background loop. Keeps playing if music was on.
    func selectTrack(_ newTrack: MusicTrack) {
        guard newTrack != track else { return }
        track = newTrack
        UserDefaults.standard.set(newTrack.rawValue, forKey: Self.trackKey)
        music?.stop()
        music = Self.makeMusicPlayer(for: newTrack)
        music?.volume = (isDucked ? Self.duckedMusicVolume : Self.musicVolume) * newTrack.volumeScale
        startMusic()
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: Self.mutedKey)
        if isMuted {
            music?.pause()
            effects.values.joined().forEach { $0.stop() }
            endPlayers.values.forEach { $0.stop() }
        } else {
            startMusic()
        }
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted else { return }
        if effect == .timeUp {
            endPlayers.values.forEach { $0.stop() }
            guard let player = endPlayers[endSound] else { return }
            player.currentTime = 0
            player.play()
            return
        }
        guard let voices = effects[effect], !voices.isEmpty else { return }
        let index = nextVoice[effect, default: 0]
        nextVoice[effect] = (index + 1) % voices.count
        let player = voices[index]
        player.currentTime = 0
        player.play()
    }

    func setMusicDucked(_ ducked: Bool) {
        guard ducked != isDucked else { return }
        isDucked = ducked
        music?.setVolume((ducked ? Self.duckedMusicVolume : Self.musicVolume) * track.volumeScale, fadeDuration: 0.4)
    }

    private static func makeMusicPlayer(for track: MusicTrack) -> AVAudioPlayer? {
        guard let url = url(for: track.rawValue), let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.numberOfLoops = -1
        player.volume = musicVolume * track.volumeScale
        player.prepareToPlay()
        return player
    }

    private static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio")
    }
}
