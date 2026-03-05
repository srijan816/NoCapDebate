//
//  TimerViewModel.swift
//  DebateFeedback
//
//

import Foundation
import SwiftData
import AVFoundation

@Observable
@MainActor
final class TimerViewModel {
    let debateSession: DebateSession
    private let modelContext: ModelContext

    // Services
    private var timerService: TimerService
    private let audioService: AudioRecordingServicing
    private let playbackService = AudioPlaybackService()
    private let uploadService: UploadServicing
    private let apiClient: APIClientProtocol

    // State
    private(set) var currentSpeakerIndex = 0
    private(set) var speakers: [(name: String, position: String, studentId: String)] = []
    private(set) var isRecording = false
    private(set) var currentRecordingURL: URL?
    private(set) var recordings: [SpeechRecording] = []

    // Playback State
    private(set) var playingRecordingId: UUID?
    var isPlaying: Bool {
        playbackService.isPlaying
    }

    // UI State
    var showError = false
    var errorMessage = ""
    var uploadProgress: [UUID: Double] = [:]

    // Warning state tracking (to avoid repeated haptics)
    @ObservationIgnored private var has60sWarningFired = false
    @ObservationIgnored private var has30sWarningFired = false
    @ObservationIgnored private var has15sWarningFired = false
    @ObservationIgnored private var sessionStartTime: Date?
    @ObservationIgnored private var recordingStartTime: Date?
    @ObservationIgnored private var hasLoggedSessionStart = false

    init(
        debateSession: DebateSession,
        modelContext: ModelContext,
        apiClient: APIClientProtocol = APIClient.shared,
        uploadService: UploadServicing = UploadService.shared,
        audioService: AudioRecordingServicing = AudioRecordingService()
    ) {
        self.debateSession = debateSession
        self.modelContext = modelContext
        self.timerService = TimerService(speechDuration: TimeInterval(debateSession.speechTimeSeconds))
        self.apiClient = apiClient
        self.uploadService = uploadService
        self.audioService = audioService

        setupSpeakers()
        updateSpeechDurationForCurrentSpeaker()
        loadExistingRecordings()
        checkMicrophonePermission()
    }

    private func loadExistingRecordings() {
        if let existingRecordings = debateSession.speechRecordings {
            let sortedRecordings = Array(existingRecordings).sorted(by: { (a: SpeechRecording, b: SpeechRecording) -> Bool in
                a.recordedAt < b.recordedAt
            })
            self.recordings = sortedRecordings
        }
    }

    // MARK: - Setup

    private func setupSpeakers() {
        guard let composition = debateSession.teamComposition else { return }
        let speakerOrder = composition.getSpeakerOrder(format: debateSession.format)

        // Convert to the format expected by speakers array
        speakers = speakerOrder.map { (studentId, position) in
            // Find student name from debateSession.students
            let studentName = debateSession.students?.first(where: { $0.id.uuidString == studentId })?.name ?? "Unknown"
            return (name: studentName, position: position, studentId: studentId)
        }
    }

    private func checkMicrophonePermission() {
        Task {
            let granted = await audioService.requestPermission()
            if !granted {
                errorMessage = Constants.ErrorMessages.microphonePermissionDenied
                showError = true
            }
        }
    }

    // MARK: - Timer Control

    var timerState: TimerService.State {
        timerService.state
    }

    var elapsedTime: TimeInterval {
        timerService.elapsedTime
    }

    var formattedTime: String {
        timerService.formattedTime
    }

    var isOvertime: Bool {
        timerService.isOvertime
    }

    var progressPercentage: Double {
        timerService.progressPercentage
    }

    // MARK: - Smart Timer Features

    /// Time remaining until expected end
    var timeRemaining: TimeInterval {
        max(0, currentSpeechDuration - elapsedTime)
    }

    private var currentSpeechDuration: TimeInterval {
        let position = currentSpeaker.position.lowercased()
        if position.contains("reply"), let replySeconds = debateSession.replyTimeSeconds {
            return TimeInterval(replySeconds)
        }
        return TimeInterval(debateSession.speechTimeSeconds)
    }

    /// Warning state based on time remaining
    enum WarningLevel {
        case none
        case oneMinute      // 60 seconds remaining
        case thirtySeconds  // 30 seconds remaining
        case fifteenSeconds // 15 seconds remaining
    }

    var currentWarningLevel: WarningLevel {
        if isOvertime {
            return .none
        }

        let remaining = timeRemaining
        if remaining <= 15 {
            return .fifteenSeconds
        } else if remaining <= 30 {
            return .thirtySeconds
        } else if remaining <= 60 {
            return .oneMinute
        } else {
            return .none
        }
    }

    /// Check and fire warnings with haptic feedback
    func checkAndFireWarnings() {
        guard isRecording && !isOvertime else {
            // Reset warning flags when not recording or in overtime
            if !isRecording {
                has60sWarningFired = false
                has30sWarningFired = false
                has15sWarningFired = false
            }
            return
        }

        switch currentWarningLevel {
        case .oneMinute:
            if !has60sWarningFired {
                HapticManager.shared.warning()
                has60sWarningFired = true
                AnalyticsService.shared.logTimerWarning(seconds: 60, speakerPosition: currentSpeaker.position)
            }
        case .thirtySeconds:
            if !has30sWarningFired {
                HapticManager.shared.warning()
                has30sWarningFired = true
                AnalyticsService.shared.logTimerWarning(seconds: 30, speakerPosition: currentSpeaker.position)
            }
        case .fifteenSeconds:
            if !has15sWarningFired {
                HapticManager.shared.warning()
                has15sWarningFired = true
                AnalyticsService.shared.logTimerWarning(seconds: 15, speakerPosition: currentSpeaker.position)
            }
        case .none:
            break
        }
    }

    func startTimer() {
        guard !isRecording else { return }

        do {
            updateSpeechDurationForCurrentSpeaker()
            // Track session started (first recording only)
            if !hasLoggedSessionStart {
                sessionStartTime = Date()
                hasLoggedSessionStart = true
                AnalyticsService.shared.logRecordingSessionStarted(
                    format: debateSession.format,
                    totalRecordings: speakers.count
                )
            }

            // Track recording started
            recordingStartTime = Date()
            AnalyticsService.shared.logRecordingStarted(
                speakerPosition: currentSpeaker.position,
                recordingNumber: currentSpeakerIndex + 1,
                totalRecordings: speakers.count
            )

            // Start recording
            let url = try audioService.startRecording(
                debateId: debateSession.id.uuidString,
                speakerName: currentSpeaker.name,
                position: currentSpeaker.position
            )

            currentRecordingURL = url
            isRecording = true

            // Start timer
            timerService.start()

        } catch {
            AnalyticsService.shared.logError(
                type: "audio_recording_error",
                message: error.localizedDescription,
                screen: "TimerMainView",
                action: "start_recording"
            )
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func stopTimer() {
        guard isRecording else { return }

        // Stop recording
        guard let result = audioService.stopRecording() else {
            // If recording failed or was already stopped, force reset state
            isRecording = false
            currentRecordingURL = nil
            timerService.stop()

            AnalyticsService.shared.logError(
                type: "audio_recording_error",
                message: "Recording failed or was stopped unexpectedly",
                screen: "TimerMainView",
                action: "stop_recording"
            )
            errorMessage = "Recording failed or was stopped unexpectedly"
            showError = true
            return
        }

        let minimumDuration: TimeInterval = 1.0
        if result.duration < minimumDuration {
            try? FileManager.deleteAudioFile(at: result.url.path)
            errorMessage = "Recording is too short. Please record at least one second of audio."
            showError = true
            return
        }

        // Calculate overtime
        let scheduledDuration = Int(currentSpeechDuration)
        let actualDuration = Int(result.duration)
        let overtime = max(0, actualDuration - scheduledDuration)

        // Track recording stopped
        AnalyticsService.shared.logRecordingStopped(
            speakerPosition: currentSpeaker.position,
            duration: actualDuration,
            scheduledDuration: scheduledDuration,
            overtime: overtime
        )

        // Stop timer
        timerService.stop()

        isRecording = false
        currentRecordingURL = nil

        // Create recording record
        let recording = SpeechRecording(
            speakerName: currentSpeaker.name,
            speakerPosition: currentSpeaker.position,
            localFilePath: result.url.path,
            durationSeconds: Int(result.duration),
            debateSession: debateSession
        )

        modelContext.insert(recording)
        recordings.append(recording)

        try? modelContext.save()

        // Check if session completed
        if recordings.count == speakers.count {
            let sessionDuration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
            AnalyticsService.shared.logRecordingSessionCompleted(
                format: debateSession.format,
                totalRecordings: speakers.count,
                totalDuration: sessionDuration
            )
        }

        // Start upload
        uploadRecording(recording)

        // Move to next speaker automatically
        if currentSpeakerIndex < speakers.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.nextSpeaker()
            }
        }
    }

    /// Ring the bell manually when user taps the bell icon
    func ringBell() {
        timerService.ringBellManually()
        AnalyticsService.shared.logManualBellPressed()
    }

    // MARK: - Speaker Navigation

    var currentSpeaker: (name: String, position: String, studentId: String) {
        speakers[currentSpeakerIndex]
    }

    var canGoBack: Bool {
        currentSpeakerIndex > 0
    }

    var canGoForward: Bool {
        currentSpeakerIndex < speakers.count - 1
    }

    var speakerProgress: String {
        "\(currentSpeakerIndex + 1) / \(speakers.count)"
    }

    func nextSpeaker() {
        guard canGoForward && !isRecording else { return }

        currentSpeakerIndex += 1
        timerService.reset()
        updateSpeechDurationForCurrentSpeaker()

        // Reset warning flags for new speaker
        has60sWarningFired = false
        has30sWarningFired = false
        has15sWarningFired = false
    }

    func previousSpeaker() {
        guard canGoBack && !isRecording else { return }

        currentSpeakerIndex -= 1
        timerService.reset()
        updateSpeechDurationForCurrentSpeaker()

        // Reset warning flags for new speaker
        has60sWarningFired = false
        has30sWarningFired = false
        has15sWarningFired = false
    }

    // MARK: - Upload Management

    private func uploadRecording(_ recording: SpeechRecording) {
        Task {
            do {
                recording.uploadStatus = .uploading
                recording.transcriptionStatus = .processing
                recording.feedbackStatus = .pending
                recording.updateAggregatedStatus()
                try? modelContext.save()

                let speechId = try await uploadService.uploadSpeech(
                    recording: recording,
                    debateSession: debateSession
                ) { progress in
                    Task { @MainActor in
                        recording.uploadProgress = progress
                        self.uploadProgress[recording.id] = progress
                    }
                }

                recording.uploadStatus = .uploaded
                recording.feedbackStatus = .processing
                recording.updateAggregatedStatus()
                recording.speechId = speechId // Store the speech ID
                try? modelContext.save()

                // Start polling for feedback
                pollForFeedback(recording: recording, speechId: speechId)

            } catch {
                recording.uploadStatus = .failed
                recording.transcriptionStatus = .failed
                recording.transcriptionErrorMessage = "Upload failed: \(error.localizedDescription)"
                recording.updateAggregatedStatus()
                try? modelContext.save()

                errorMessage = "Failed to upload \(recording.speakerName)'s speech: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    func retryUpload(for recording: SpeechRecording) {
        uploadRecording(recording)
    }

    // MARK: - Feedback Polling

    private func pollForFeedback(recording: SpeechRecording, speechId: String) {
        Task {
            var attempts = 0
            let maxAttempts = 60 // 5 minutes max

            while attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(Constants.API.feedbackPollingInterval * 1_000_000_000))

                do {
                    let status: SpeechStatusResponse = try await apiClient.request(
                        endpoint: .getSpeechStatus(speechId: speechId)
                    )

                    let isTerminal = apply(statusResponse: status, to: recording)
                    if isTerminal {
                        return
                    }

                } catch {
                    print("Polling error: \(error)")
                }

                attempts += 1
            }

            // Timeout
            recording.feedbackStatus = .failed
            recording.feedbackErrorMessage = "Timed out waiting for feedback"
            recording.updateAggregatedStatus()
            try? modelContext.save()
        }
    }

    private func apply(statusResponse: SpeechStatusResponse, to recording: SpeechRecording) -> Bool {
        let lowerStatus = statusResponse.status.lowercased()

        if let transStatus = statusResponse.transcriptionStatus {
            recording.transcriptionStatus = ProcessingStatus(apiStatus: transStatus)
        } else if lowerStatus == "complete" && recording.transcriptionStatus != .complete {
            recording.transcriptionStatus = .complete
        }

        if let transError = statusResponse.transcriptionError, !transError.isEmpty {
            recording.transcriptionErrorMessage = transError
            recording.transcriptionStatus = .failed
        }

        if let feedbackStatus = statusResponse.feedbackStatus {
            recording.feedbackStatus = ProcessingStatus(apiStatus: feedbackStatus)
        } else if lowerStatus == "complete" {
            recording.feedbackStatus = .complete
        }

        if let feedbackError = statusResponse.feedbackError, !feedbackError.isEmpty {
            recording.feedbackErrorMessage = feedbackError
            recording.feedbackStatus = .failed
        }

        if let feedbackUrl = statusResponse.feedbackUrl, !feedbackUrl.isEmpty {
            recording.feedbackUrl = feedbackUrl
        }

        if let transcriptUrl = statusResponse.transcriptUrl, !transcriptUrl.isEmpty {
            recording.transcriptUrl = transcriptUrl
        }

        if let transcriptText = statusResponse.transcriptText, !transcriptText.isEmpty {
            recording.transcriptText = transcriptText
        }

        if let generalError = statusResponse.errorMessage, !generalError.isEmpty {
            if recording.feedbackStatus == .failed {
                recording.feedbackErrorMessage = generalError
            } else if recording.transcriptionStatus == .failed {
                recording.transcriptionErrorMessage = generalError
            }
        }

        recording.updateAggregatedStatus()
        try? modelContext.save()

        if recording.transcriptionStatus == .failed || recording.feedbackStatus == .failed {
            return true
        }

        if recording.feedbackStatus == .complete {
            return true
        }

        return false
    }

    // MARK: - Completion

    var isDebateComplete: Bool {
        recordings.count == speakers.count
    }

    var completedSpeeches: Int {
        recordings.count
    }

    func viewFeedback() {
        // Navigation handled by coordinator
    }

    private func updateSpeechDurationForCurrentSpeaker() {
        timerService.updateSpeechDuration(currentSpeechDuration)
    }

    // MARK: - Playback Management

    func togglePlayback(for recording: SpeechRecording) {
        // If this recording is currently playing, pause it
        if playingRecordingId == recording.id && isPlaying {
            playbackService.pause()
            return
        }

        // If this recording was paused, resume it
        if playingRecordingId == recording.id && !isPlaying {
            playbackService.resume()
            return
        }

        // Otherwise, start playing this recording
        playRecording(recording)
    }

    private func playRecording(_ recording: SpeechRecording) {
        let url = URL(fileURLWithPath: recording.localFilePath)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: recording.localFilePath) else {
            errorMessage = "Recording file not found. It may have been deleted."
            showError = true
            return
        }

        do {
            try playbackService.play(from: url)
            playingRecordingId = recording.id
        } catch {
            errorMessage = "Failed to play recording: \(error.localizedDescription)"
            showError = true
        }
    }

    func stopPlayback() {
        playbackService.stop()
        playingRecordingId = nil
    }

    func getPlaybackProgress(for recording: SpeechRecording) -> Double {
        guard playingRecordingId == recording.id else { return 0 }
        return playbackService.progress
    }

    func getPlaybackTime(for recording: SpeechRecording) -> String {
        guard playingRecordingId == recording.id else {
            return formatDuration(recording.durationSeconds)
        }
        return "\(playbackService.formattedCurrentTime) / \(playbackService.formattedDuration)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Cleanup

    deinit {
        // Note: Cannot reliably cancel recording in deinit due to async/MainActor requirements
        // Recording will be stopped when the service is deallocated
        playbackService.stop()
    }
}
