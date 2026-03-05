import Foundation
import CryptoKit

/// Main analytics service - single point of access for all analytics
class AnalyticsService {
    static let shared = AnalyticsService()

    private var providers: [AnalyticsProvider] = []
    private var isInitialized = false
    private let queue = DispatchQueue(label: "com.debatefeedback.analytics", qos: .utility)

    private init() {
        // Initialization happens in configure() method
    }

    /// Configure analytics with device ID
    func configure(deviceId: String) {
        queue.sync {
            guard !isInitialized else { return }

            // Add providers based on environment
            #if DEBUG
            providers.append(AnalyticsDebugger())
            #endif

            // Add backend provider
            providers.append(BackendAnalyticsProvider(deviceId: deviceId))

            // TODO: Add Firebase provider when Firebase SDK is integrated
            // providers.append(FirebaseAnalyticsProvider())

            isInitialized = true
            print("✅ Analytics Service configured with \(providers.count) provider(s)")
        }
    }

    // MARK: - Core Methods

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        queue.async {
            self.providers.forEach { $0.logEvent(eventName, parameters: parameters) }
        }
    }

    func setUserProperty(_ value: String, forName name: String) {
        queue.async {
            self.providers.forEach { $0.setUserProperty(value, forName: name) }
        }
    }

    func setUserId(_ userId: String?) {
        // Hash user ID for privacy
        let hashedId = userId.map { hashString($0) }
        queue.async {
            self.providers.forEach { $0.setUserId(hashedId) }
        }
    }

    func logScreenView(_ screenName: String, screenClass: String) {
        queue.async {
            self.providers.forEach { $0.logScreenView(screenName, screenClass: screenClass) }
        }
    }

    func resetAnalyticsData() {
        queue.async {
            self.providers.forEach { $0.resetAnalyticsData() }
        }
    }

    // MARK: - Privacy Helpers

    /// Hash a string using SHA-256 for privacy
    private func hashString(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Create hashed user ID from teacher name
    func createUserHash(for teacherName: String, deviceId: String) -> String {
        return hashString("\(teacherName)_\(deviceId)")
    }

    /// Create hashed student ID
    func createStudentHash(for studentName: String) -> String {
        return hashString(studentName)
    }
}

// MARK: - Authentication Analytics

extension AnalyticsService {
    func logLoginInitiated() {
        logEvent(AnalyticsEvents.authLoginInitiated)
    }

    func logLoginSuccess(teacherName: String, deviceId: String, isReturning: Bool) {
        let userHash = createUserHash(for: teacherName, deviceId: deviceId)
        setUserId(userHash)
        setUserProperty("teacher", forName: AnalyticsProperties.userType)
        setUserProperty(deviceId, forName: AnalyticsProperties.deviceId)

        logEvent(AnalyticsEvents.authLoginSuccess, parameters: [
            AnalyticsProperties.isReturningUser: isReturning,
            AnalyticsProperties.authMethod: "teacher"
        ])
    }

    func logGuestModeSelected(deviceId: String) {
        setUserId("guest_\(deviceId)")
        setUserProperty("guest", forName: AnalyticsProperties.userType)

        logEvent(AnalyticsEvents.authGuestModeSelected)
    }

    func logLogout() {
        logEvent(AnalyticsEvents.authLogout)
        resetAnalyticsData()
    }
}

// MARK: - Setup Analytics

extension AnalyticsService {
    func logSetupStarted() {
        logEvent(AnalyticsEvents.setupStarted)
    }

    func logSetupStep1Completed(
        format: DebateFormat,
        studentLevel: StudentLevel,
        motionLength: Int,
        speechTime: Int,
        replyTime: Int?,
        usedSchedule: Bool
    ) {
        logEvent(AnalyticsEvents.setupStep1Completed, parameters: [
            AnalyticsProperties.debateFormat: format.rawValue,
            AnalyticsProperties.studentLevel: studentLevel.rawValue,
            AnalyticsProperties.motionLength: motionLength,
            AnalyticsProperties.speechTimeSeconds: speechTime,
            AnalyticsProperties.replyTimeSeconds: replyTime ?? 0,
            AnalyticsProperties.usedScheduleIntegration: usedSchedule
        ])
    }

    func logSetupStep2Started() {
        logEvent(AnalyticsEvents.setupStep2Started)
    }

    func logSetupCompleted(
        format: DebateFormat,
        numStudents: Int,
        totalSetupTime: TimeInterval
    ) {
        logEvent(AnalyticsEvents.setupCompleted, parameters: [
            AnalyticsProperties.debateFormat: format.rawValue,
            AnalyticsProperties.numStudents: numStudents,
            AnalyticsProperties.totalSetupTime: Int(totalSetupTime)
        ])
    }

    func logSetupAbandoned(currentStep: Int) {
        logEvent(AnalyticsEvents.setupAbandoned, parameters: [
            "step_abandoned": currentStep
        ])
    }

    func logSetupStudentAdded(studentCount: Int) {
        logEvent(AnalyticsEvents.setupStudentAdded, parameters: [
            AnalyticsProperties.numStudents: studentCount
        ])
    }

    func logSetupStudentAssigned(team: String, position: Int) {
        logEvent(AnalyticsEvents.setupStudentAssigned, parameters: [
            "team": team,
            "position": position
        ])
    }

    func logSetupStudentReordered(team: String, fromPosition: Int, toPosition: Int) {
        logEvent(AnalyticsEvents.setupStudentReordered, parameters: [
            "team": team,
            "from_position": fromPosition,
            "to_position": toPosition
        ])
    }
}

// MARK: - Recording Analytics

extension AnalyticsService {
    func logRecordingSessionStarted(format: DebateFormat, totalRecordings: Int) {
        logEvent(AnalyticsEvents.recordingSessionStarted, parameters: [
            AnalyticsProperties.debateFormat: format.rawValue,
            AnalyticsProperties.totalRecordingsInSession: totalRecordings
        ])
    }

    func logRecordingStarted(
        speakerPosition: String,
        recordingNumber: Int,
        totalRecordings: Int
    ) {
        logEvent(AnalyticsEvents.recordingStarted, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition,
            AnalyticsProperties.recordingNumber: recordingNumber,
            AnalyticsProperties.totalRecordingsInSession: totalRecordings
        ])
    }

    func logRecordingStopped(
        speakerPosition: String,
        duration: Int,
        scheduledDuration: Int,
        overtime: Int
    ) {
        logEvent(AnalyticsEvents.recordingStopped, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition,
            AnalyticsProperties.recordingDuration: duration,
            AnalyticsProperties.scheduledDuration: scheduledDuration,
            AnalyticsProperties.overtimeSeconds: overtime
        ])

        if overtime > 0 {
            logEvent(AnalyticsEvents.timerOvertimeEntered, parameters: [
                AnalyticsProperties.speakerPosition: speakerPosition,
                AnalyticsProperties.overtimeSeconds: overtime
            ])
        }
    }

    func logRecordingSessionCompleted(
        format: DebateFormat,
        totalRecordings: Int,
        totalDuration: TimeInterval
    ) {
        logEvent(AnalyticsEvents.recordingSessionCompleted, parameters: [
            AnalyticsProperties.debateFormat: format.rawValue,
            AnalyticsProperties.totalRecordingsInSession: totalRecordings,
            "session_duration_seconds": Int(totalDuration)
        ])
    }

    func logTimerWarning(seconds: Int, speakerPosition: String) {
        logEvent(AnalyticsEvents.timerWarningShown, parameters: [
            "warning_seconds": seconds,
            AnalyticsProperties.speakerPosition: speakerPosition
        ])
    }

    func logManualBellPressed() {
        logEvent(AnalyticsEvents.timerManualBellPressed)
    }
}

// MARK: - Upload Analytics

extension AnalyticsService {
    func logUploadStarted(
        speechId: Int?,
        fileSizeMB: Double,
        networkType: String
    ) {
        logEvent(AnalyticsEvents.uploadStarted, parameters: [
            "speech_id": speechId as Any,
            AnalyticsProperties.fileSizeMB: fileSizeMB,
            AnalyticsProperties.networkType: networkType
        ])
    }

    func logUploadCompleted(
        speechId: Int?,
        duration: TimeInterval,
        fileSizeMB: Double
    ) {
        logEvent(AnalyticsEvents.uploadCompleted, parameters: [
            "speech_id": speechId as Any,
            AnalyticsProperties.uploadDuration: Int(duration),
            AnalyticsProperties.fileSizeMB: fileSizeMB
        ])
    }

    func logUploadFailed(
        speechId: Int?,
        reason: String,
        retryCount: Int
    ) {
        logEvent(AnalyticsEvents.uploadFailed, parameters: [
            "speech_id": speechId as Any,
            AnalyticsProperties.failureReason: reason,
            AnalyticsProperties.retryCount: retryCount
        ])
    }
}

// MARK: - Feedback Analytics

extension AnalyticsService {
    func logFeedbackListViewed(
        totalSpeeches: Int,
        readySpeeches: Int,
        processingSpeeches: Int
    ) {
        logEvent(AnalyticsEvents.feedbackListViewed, parameters: [
            AnalyticsProperties.totalSpeeches: totalSpeeches,
            AnalyticsProperties.readySpeeches: readySpeeches,
            AnalyticsProperties.processingSpeeches: processingSpeeches,
            AnalyticsProperties.completionPercentage: totalSpeeches > 0 ? Double(readySpeeches) / Double(totalSpeeches) : 0
        ])
    }

    func logFeedbackDetailViewed(
        speakerPosition: String,
        hasPlayableMoments: Bool,
        playableMomentsCount: Int
    ) {
        logEvent(AnalyticsEvents.feedbackDetailViewed, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition,
            "has_playable_moments": hasPlayableMoments,
            AnalyticsProperties.totalPlayableMoments: playableMomentsCount
        ])
    }

    func logPlayableMomentClicked(
        speakerPosition: String,
        timestamp: String,
        index: Int,
        totalMoments: Int
    ) {
        logEvent(AnalyticsEvents.playableMomentClicked, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition,
            AnalyticsProperties.playableMomentTimestamp: timestamp,
            AnalyticsProperties.playableMomentIndex: index,
            AnalyticsProperties.totalPlayableMoments: totalMoments
        ])
    }

    func logFeedbackTabSwitched(to tab: String) {
        logEvent(AnalyticsEvents.feedbackTabSwitched, parameters: [
            AnalyticsProperties.activeTab: tab
        ])
    }

    func logTranscriptViewed(speakerPosition: String) {
        logEvent(AnalyticsEvents.transcriptViewed, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition
        ])
    }

    func logAudioPlaybackStarted(speakerPosition: String, fromTimestamp: Double?) {
        logEvent(AnalyticsEvents.audioPlaybackStarted, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition,
            "from_timestamp": fromTimestamp as Any
        ])
    }

    func logAudioPlaybackStopped(speakerPosition: String, duration: TimeInterval) {
        logEvent(AnalyticsEvents.audioPlaybackStopped, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition,
            "playback_duration": Int(duration)
        ])
    }

    func logFeedbackSharedSafari(speakerPosition: String) {
        logEvent(AnalyticsEvents.feedbackSharedSafari, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition
        ])
    }

    func logFeedbackSharedSystem(speakerPosition: String) {
        logEvent(AnalyticsEvents.feedbackSharedSystem, parameters: [
            AnalyticsProperties.speakerPosition: speakerPosition
        ])
    }
}

// MARK: - History Analytics

extension AnalyticsService {
    func logHistoryViewed(totalDebates: Int) {
        logEvent(AnalyticsEvents.historyViewed, parameters: [
            "total_debates": totalDebates
        ])
    }

    func logHistorySearchPerformed(query: String, resultsCount: Int) {
        logEvent(AnalyticsEvents.historySearchPerformed, parameters: [
            "query_length": query.count,
            "results_count": resultsCount
        ])
    }

    func logHistoryFilterApplied(format: DebateFormat?, studentLevel: StudentLevel?) {
        logEvent(AnalyticsEvents.historyFilterApplied, parameters: [
            "filter_format": format?.rawValue as Any,
            "filter_student_level": studentLevel?.rawValue as Any
        ])
    }

    func logHistoryFilterCleared() {
        logEvent(AnalyticsEvents.historyFilterCleared, parameters: [:])
    }

    func logHistoryDebateSelected(debateId: String, format: DebateFormat, studentLevel: StudentLevel) {
        logEvent(AnalyticsEvents.historyDebateSelected, parameters: [
            "debate_id": debateId,
            AnalyticsProperties.debateFormat: format.rawValue,
            AnalyticsProperties.studentLevel: studentLevel.rawValue
        ])
    }

    func logHistoryDebateDeleted(debateId: String, debateAgeDays: Int) {
        logEvent(AnalyticsEvents.historyDebateDeleted, parameters: [
            "debate_id": debateId,
            "debate_age_days": debateAgeDays
        ])
    }
}

// MARK: - Error Analytics

extension AnalyticsService {
    func logError(
        type: String,
        message: String,
        code: String? = nil,
        screen: String,
        action: String? = nil
    ) {
        logEvent(AnalyticsEvents.errorOccurred, parameters: [
            AnalyticsProperties.errorType: type,
            AnalyticsProperties.errorMessage: message,
            AnalyticsProperties.errorCode: code ?? "unknown",
            AnalyticsProperties.screenName: screen,
            AnalyticsProperties.userAction: action ?? "unknown"
        ])
    }

    func logAPIError(
        endpoint: String,
        statusCode: Int,
        message: String
    ) {
        logEvent(AnalyticsEvents.apiError, parameters: [
            "endpoint": endpoint,
            "status_code": statusCode,
            AnalyticsProperties.errorMessage: message
        ])
    }

    func logNetworkError(message: String) {
        logEvent(AnalyticsEvents.networkError, parameters: [
            AnalyticsProperties.errorMessage: message
        ])
    }
}

// MARK: - Session Analytics

extension AnalyticsService {
    func logAppOpened() {
        logEvent(AnalyticsEvents.appOpened)
    }

    func logAppBackgrounded(sessionDuration: TimeInterval) {
        logEvent(AnalyticsEvents.appBackgrounded, parameters: [
            AnalyticsProperties.sessionDuration: Int(sessionDuration)
        ])
    }
}
