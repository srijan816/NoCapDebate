//
//  AudioRecordingService.swift
//  DebateFeedback
//
//

import AVFoundation
import Foundation

protocol AudioRecordingServicing {
    func requestPermission() async -> Bool
    func startRecording(
        debateId: String,
        speakerName: String,
        position: String
    ) throws -> URL
    func stopRecording() -> (url: URL, duration: TimeInterval)?
}

@Observable
final class AudioRecordingService: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

    private(set) var isRecording = false
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var hasPermission = false

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let granted = await AudioSessionHelper.shared.requestMicrophonePermission()
        hasPermission = granted
        return granted
    }

    func checkPermission() {
        hasPermission = AudioSessionHelper.shared.microphonePermissionStatus
    }

    // MARK: - Recording Control

    func startRecording(
        debateId: String,
        speakerName: String,
        position: String
    ) throws -> URL {
        guard hasPermission else {
            throw RecordingError.permissionDenied
        }

        // Configure audio session
        try AudioSessionHelper.shared.configureForRecording()

        // Generate filename and URL
        let filename = FileManager.generateAudioFilename(
            debateId: debateId,
            speakerName: speakerName,
            position: position
        )
        let url = FileManager.audioFileURL(filename: filename)

        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Constants.Audio.sampleRate,
            AVNumberOfChannelsKey: Constants.Audio.numberOfChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: Constants.Audio.bitRate
        ]

        // Create and start recorder
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true

        guard audioRecorder?.record() == true else {
            throw RecordingError.failedToStart
        }

        currentRecordingURL = url
        isRecording = true
        recordingDuration = 0

        return url
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder,
              isRecording,
              let url = currentRecordingURL else {
            return nil
        }

        // Capture duration before stopping
        let duration = recorder.currentTime
        
        recorder.stop()
        isRecording = false

        recordingDuration = duration

        currentRecordingURL = nil
        audioRecorder = nil

        return (url, duration)
    }

    func pauseRecording() {
        guard let recorder = audioRecorder, isRecording else { return }

        recorder.pause()
        isRecording = false
    }

    func resumeRecording() {
        guard let recorder = audioRecorder, !isRecording else { return }

        recorder.record()
        isRecording = true
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }

        recorder.stop()
        isRecording = false

        if let url = currentRecordingURL {
            try? FileManager.deleteAudioFile(at: url.path)
        }

        currentRecordingURL = nil
        audioRecorder = nil
        recordingDuration = 0
    }

    // MARK: - Audio Level Monitoring

    func updateMeters() -> Float {
        guard let recorder = audioRecorder, isRecording else {
            return 0.0
        }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)

        // Convert dB to 0-1 range
        let normalized = pow(10, averagePower / 20)
        return normalized
    }
}

extension AudioRecordingService: AudioRecordingServicing {}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            // Recording failed or was interrupted
            isRecording = false
            currentRecordingURL = nil
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording encode error: \(error?.localizedDescription ?? "Unknown")")
        isRecording = false
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case permissionDenied
    case failedToStart
    case audioSessionError
    case fileError

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return Constants.ErrorMessages.microphonePermissionDenied
        case .failedToStart:
            return Constants.ErrorMessages.recordingFailed
        case .audioSessionError:
            return "Failed to configure audio session"
        case .fileError:
            return "Failed to create recording file"
        }
    }
}
