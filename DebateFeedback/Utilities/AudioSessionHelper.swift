//
//  AudioSessionHelper.swift
//  DebateFeedback
//
//

import AVFoundation
import Foundation

final class AudioSessionHelper {
    static let shared = AudioSessionHelper()

    private init() {}

    /// Configures audio session for recording and playback
    func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()



        // Use new option for iOS 18+ compatibility while maintaining functionality
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )

        try session.setActive(true)
    }

    /// Configures audio session for playback only (bells)
    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playback,
            mode: .default,
            options: []
        )

        try session.setActive(true)
    }

    /// Requests microphone permission
    func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Checks current microphone permission status
    var microphonePermissionStatus: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    /// Deactivates audio session
    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
