//
//  TimerService.swift
//  DebateFeedback
//
//

import AVFoundation
import Foundation
import UIKit

@Observable
@MainActor
final class TimerService {
    enum State {
        case idle
        case running
        case paused
        case stopped
    }

    private(set) var state: State = .idle
    private(set) var elapsedTime: TimeInterval = 0

    private var startTime: Date?
    private var displayLink: CADisplayLink?
    private var bellPlayers: [AVAudioPlayer] = []
    private var bellSoundURL: URL?
    private let bellGap: TimeInterval = 0.18

    private(set) var speechDuration: TimeInterval
    private var bellsScheduled: [TimeInterval] = []
    private var bellsFired: Set<Int> = []

    init(speechDuration: TimeInterval) {
        self.speechDuration = speechDuration
        setupBellPlayers()
        scheduleBells()
    }

    func updateSpeechDuration(_ duration: TimeInterval) {
        speechDuration = duration
        bellsFired.removeAll()
        scheduleBells()
    }

    // MARK: - Timer Control

    func start() {
        guard state == .idle else { return }

        startTime = Date()
        state = .running
        elapsedTime = 0
        bellsFired.removeAll()

        // Setup display link for smooth updates
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        guard state == .running || state == .paused else { return }

        state = .stopped
        displayLink?.invalidate()
        displayLink = nil
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        displayLink?.invalidate()
        displayLink = nil
    }

    func resume() {
        guard state == .paused else { return }

        // Adjust start time to account for pause
        if startTime != nil {
            startTime = Date().addingTimeInterval(-elapsedTime)
        }

        state = .running
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func reset() {
        stop()
        state = .idle
        elapsedTime = 0
        startTime = nil
        bellsFired.removeAll()
    }

    // MARK: - Private Methods

    @objc private func update() {
        guard let start = startTime, state == .running else { return }

        elapsedTime = Date().timeIntervalSince(start)

        // Check if any bells need to fire
        checkAndFireBells()
    }

    private func scheduleBells() {
        bellsScheduled = []

        // 1 bell at 1:00
        if speechDuration >= 60 {
            bellsScheduled.append(60.0)
        }

        // 1 bell at (duration - 1:00)
        if speechDuration >= 120 {
            bellsScheduled.append(speechDuration - 60.0)
        }

        // 2 bells at duration
        bellsScheduled.append(speechDuration)

        // 3 bells every 15s after duration
        var overtimePoint = speechDuration + 15.0
        for _ in 0..<20 { // Max 20 overtime bells (5 minutes overtime)
            bellsScheduled.append(overtimePoint)
            overtimePoint += 15.0
        }
    }

    private func checkAndFireBells() {
        for (index, bellTime) in bellsScheduled.enumerated() {
            // Check if bell time has passed and hasn't been fired yet
            if elapsedTime >= bellTime && !bellsFired.contains(index) {
                bellsFired.insert(index)
                fireBell(for: bellTime)
            }
        }
    }

    private func fireBell(for time: TimeInterval) {
        let bellCount: Int

        if time == 60.0 || time == speechDuration - 60.0 {
            bellCount = 1
        } else if time == speechDuration {
            bellCount = 2
        } else {
            bellCount = 3 // Overtime
        }

        playBell(count: bellCount)
    }

    // MARK: - Bell Audio

    private func setupBellPlayers() {
        if let url = Bundle.main.url(forResource: "bell", withExtension: "wav") {
            bellSoundURL = url
            // Prime the audio system with a single player
            if let warmupPlayer = try? AVAudioPlayer(contentsOf: url) {
                warmupPlayer.prepareToPlay()
                bellPlayers.append(warmupPlayer)
            }
        } else {
            print("Warning: bell.wav not found in bundle. Bell sounds will be silent.")
        }
    }

    private func playBell(count: Int) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        playBellSound(repetitions: count)

        print("🔔 Bell fired: \(count) ding(s) at \(elapsedTime.toMinutesSeconds())")
    }

    private func playBellSound(repetitions: Int) {
        guard let url = bellSoundURL else { return }

        for index in 0..<repetitions {
            let delay = bellGap * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }

                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.play()
                    self.bellPlayers.append(player)

                    let cleanupDelay = player.duration + 0.2
                    DispatchQueue.main.asyncAfter(deadline: .now() + cleanupDelay) { [weak self, weak player] in
                        guard let self, let player else { return }
                        self.bellPlayers.removeAll { $0 === player }
                    }

                } catch {
                    print("Bell playback error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Manual Bell Control

    /// Manually trigger a single bell sound (e.g., when user taps the bell icon)
    func ringBellManually() {
        playBell(count: 1)
    }

    // MARK: - Computed Properties

    var isRunning: Bool {
        state == .running
    }

    var formattedTime: String {
        elapsedTime.toMinutesSeconds()
    }

    var isOvertime: Bool {
        elapsedTime > speechDuration
    }

    var progressPercentage: Double {
        min(elapsedTime / speechDuration, 1.0)
    }

    deinit {
        // Note: displayLink cleanup handled automatically when object is deallocated
        // Cannot use async Task in deinit as it creates a closure that outlives deinit
    }
}
