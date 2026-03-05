//
//  AudioPlaybackService.swift
//  DebateFeedback
//
//

import AVFoundation
import Foundation

@Observable
final class AudioPlaybackService: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private(set) var currentFileURL: URL?

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    // Timer to update playback progress
    private var progressTimer: Timer?

    // MARK: - Playback Control

    private(set) var endTime: TimeInterval?

    // MARK: - Playback Control

    func play(from url: URL, startingAt startTime: TimeInterval? = nil, endingAt endTime: TimeInterval? = nil) throws {
        // Stop any current playback
        stop()

        // Configure audio session for playback
        try AudioSessionHelper.shared.configureForPlayback()

        // Create player
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()

        guard let player = audioPlayer else {
            throw PlaybackError.failedToInitialize
        }

        duration = player.duration
        currentFileURL = url
        self.endTime = endTime

        if let startTime = startTime {
            let clampedTime = max(0, min(startTime, player.duration))
            player.currentTime = clampedTime
            currentTime = clampedTime
        }

        // Start playback
        guard player.play() else {
            throw PlaybackError.failedToStart
        }

        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        guard let player = audioPlayer, isPlaying else { return }

        player.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        guard let player = audioPlayer, !isPlaying else { return }

        // If we finished playing a range and user hits resume, check if we should clear endTime or specific behavior?
        // Typically resume just continues from where it is. If we are past endTime, maybe we should clear it?
        // For simplicity, let's keep endTime. If we are past it, we might stop immediately in the timer loop, 
        // effectively preventing playback past the point unless user seeks back.
        // OR we clear it on resume? Let's keep it simple: strict range unless cleared.
        // But user might want to continue listening. Let's clear endTime on manual resume/seek if needed?
        // Standard behavior: resume continues. If strict range was for "Preview", maybe.
        // Let's assume play(range) sets it. Resume keeps it.
        
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
        endTime = nil
        stopProgressTimer()
        audioPlayer = nil
        currentFileURL = nil
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }

        player.currentTime = time
        currentTime = time
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            
            // Check for end time
            if let end = self.endTime, self.currentTime >= end {
                self.pause() // Pause instead of stop to keep player active? 
                // Or stop? The instruction says "audio should stop".
                // If we stop(), we lose state. Pause seems better.
                // But typically range playback stops.
                self.pause()
                // Maybe seek back to start? No, just pause at end is fine.
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Helper Properties

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Cleanup

    deinit {
        stop()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Playback decode error: \(error?.localizedDescription ?? "Unknown")")
        isPlaying = false
        stopProgressTimer()
    }
}

// MARK: - Playback Errors

enum PlaybackError: LocalizedError {
    case failedToInitialize
    case failedToStart
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .failedToInitialize:
            return "Failed to initialize audio player"
        case .failedToStart:
            return "Failed to start playback"
        case .fileNotFound:
            return "Audio file not found"
        }
    }
}
