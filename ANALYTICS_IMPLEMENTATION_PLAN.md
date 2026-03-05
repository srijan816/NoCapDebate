# DebateFeedback Analytics - Technical Implementation Plan

## Overview

This document provides step-by-step technical guidance for implementing the analytics strategy outlined in `ANALYTICS_STRATEGY.md`. It includes code architecture, file structure, integration points, and specific implementation examples.

---

## Technology Stack Recommendation

### Primary Recommendation: Firebase Analytics
**Why Firebase:**
- Free tier with generous limits
- Native iOS SDK with SwiftUI support
- Automatic screen tracking
- Built-in user properties and audiences
- Integration with Firebase Crashlytics for error tracking
- BigQuery export for advanced analysis
- Google Analytics 4 integration
- Strong privacy controls (Apple-friendly)

**Alternatives Considered:**
- **Mixpanel**: Better funnel analysis, more expensive, great for SaaS
- **Amplitude**: Best product analytics, behavioral cohorts, paid only
- **PostHog**: Open-source, self-hosted option, more complex setup
- **Custom Solution**: Full control, but requires backend infrastructure

**Decision**: Firebase Analytics for MVP, migrate to Amplitude if budget allows and need advanced cohort analysis.

---

## Architecture Design

### 1. Service Layer Pattern

```
DebateFeedback/
├── Core/
│   ├── Services/
│   │   ├── Analytics/
│   │   │   ├── AnalyticsService.swift          # Main service interface
│   │   │   ├── AnalyticsProvider.swift         # Protocol definition
│   │   │   ├── FirebaseAnalyticsProvider.swift # Firebase implementation
│   │   │   ├── AnalyticsEvents.swift           # Event name constants
│   │   │   ├── AnalyticsProperties.swift       # Property builders
│   │   │   └── AnalyticsDebugger.swift         # Debug mode logger
```

### 2. Protocol-Based Design

**Benefits:**
- Easy to swap analytics providers
- Testable (mock analytics in unit tests)
- Multi-provider support (log to Firebase + custom backend)
- Debug mode without production overhead

**Implementation:**

```swift
// AnalyticsProvider.swift
protocol AnalyticsProvider {
    /// Log a custom event with optional parameters
    func logEvent(_ eventName: String, parameters: [String: Any]?)

    /// Set a user property
    func setUserProperty(_ value: String, forName name: String)

    /// Set user identifier
    func setUserId(_ userId: String)

    /// Log screen view
    func logScreenView(_ screenName: String, screenClass: String)

    /// Reset analytics data (for logout)
    func resetAnalyticsData()
}
```

---

## Phase 1 Implementation: Foundation

### Step 1: Install Firebase SDK

**Add to project via Swift Package Manager:**

1. Open Xcode → File → Add Package Dependencies
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: 10.0.0+
4. Add packages:
   - FirebaseAnalytics
   - FirebaseCrashlytics (for error tracking)

**Add Firebase configuration:**

1. Go to Firebase Console (https://console.firebase.google.com)
2. Create new project: "DebateFeedback"
3. Add iOS app with bundle ID: `com.yourcompany.DebateFeedback`
4. Download `GoogleService-Info.plist`
5. Add to Xcode project root (same level as `Info.plist`)
6. Ensure it's included in target

### Step 2: Initialize Firebase

**Edit `DebateFeedbackApp.swift`:**

```swift
import SwiftUI
import SwiftData
import Firebase

@main
struct DebateFeedbackApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        // Initialize Firebase
        FirebaseApp.configure()

        // Optional: Enable analytics debug mode in development
        #if DEBUG
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
                .modelContainer(coordinator.modelContainer)
        }
    }
}
```

### Step 3: Create Analytics Service Layer

**Create `AnalyticsProvider.swift`:**

```swift
import Foundation

/// Protocol for analytics providers (Firebase, Mixpanel, custom, etc.)
protocol AnalyticsProvider {
    func logEvent(_ eventName: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String, forName name: String)
    func setUserId(_ userId: String?)
    func logScreenView(_ screenName: String, screenClass: String)
    func resetAnalyticsData()
}

/// Extension with default implementations
extension AnalyticsProvider {
    func logEvent(_ eventName: String) {
        logEvent(eventName, parameters: nil)
    }
}
```

**Create `FirebaseAnalyticsProvider.swift`:**

```swift
import Foundation
import FirebaseAnalytics

/// Firebase implementation of AnalyticsProvider
class FirebaseAnalyticsProvider: AnalyticsProvider {

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        // Convert parameters to Firebase format
        var firebaseParams: [String: Any]?
        if let params = parameters {
            firebaseParams = params.mapValues { value -> Any in
                // Firebase supports String, Int, Double, Bool
                // Convert other types to String
                if value is String || value is Int || value is Double || value is Bool {
                    return value
                }
                return String(describing: value)
            }
        }

        Analytics.logEvent(eventName, parameters: firebaseParams)
    }

    func setUserProperty(_ value: String, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    func logScreenView(_ screenName: String, screenClass: String) {
        logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }

    func resetAnalyticsData() {
        Analytics.resetAnalyticsData()
        Analytics.setUserID(nil)
    }
}
```

**Create `AnalyticsDebugger.swift` (for development):**

```swift
import Foundation
import OSLog

/// Debug-only analytics provider that logs to console
class AnalyticsDebugger: AnalyticsProvider {
    private let logger = Logger(subsystem: "com.debatemateapp", category: "Analytics")

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        var logMessage = "📊 Event: \(eventName)"
        if let params = parameters {
            let paramString = params.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logMessage += " | Params: [\(paramString)]"
        }
        logger.info("\(logMessage)")
        print(logMessage) // Also print for easy viewing
    }

    func setUserProperty(_ value: String, forName name: String) {
        logger.info("👤 User Property: \(name) = \(value)")
        print("👤 User Property: \(name) = \(value)")
    }

    func setUserId(_ userId: String?) {
        logger.info("🆔 User ID: \(userId ?? "nil")")
        print("🆔 User ID: \(userId ?? "nil")")
    }

    func logScreenView(_ screenName: String, screenClass: String) {
        logger.info("📱 Screen View: \(screenName) (\(screenClass))")
        print("📱 Screen View: \(screenName) (\(screenClass))")
    }

    func resetAnalyticsData() {
        logger.info("🔄 Analytics data reset")
        print("🔄 Analytics data reset")
    }
}
```

**Create `AnalyticsService.swift` (main interface):**

```swift
import Foundation
import CryptoKit

/// Main analytics service - single point of access for all analytics
class AnalyticsService {
    static let shared = AnalyticsService()

    private var providers: [AnalyticsProvider] = []

    private init() {
        // Add providers based on environment
        #if DEBUG
        providers.append(AnalyticsDebugger())
        #endif

        providers.append(FirebaseAnalyticsProvider())
    }

    // MARK: - Core Methods

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        providers.forEach { $0.logEvent(eventName, parameters: parameters) }
    }

    func setUserProperty(_ value: String, forName name: String) {
        providers.forEach { $0.setUserProperty(value, forName: name) }
    }

    func setUserId(_ userId: String?) {
        // Hash user ID for privacy
        let hashedId = userId.map { hashString($0) }
        providers.forEach { $0.setUserId(hashedId) }
    }

    func logScreenView(_ screenName: String, screenClass: String) {
        providers.forEach { $0.logScreenView(screenName, screenClass: screenClass) }
    }

    func resetAnalyticsData() {
        providers.forEach { $0.resetAnalyticsData() }
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
```

### Step 4: Define Event Constants

**Create `AnalyticsEvents.swift`:**

```swift
import Foundation

/// All analytics event names
/// Naming convention: category_action_object (snake_case)
struct AnalyticsEvents {

    // MARK: - Authentication Events
    static let authLoginInitiated = "auth_login_initiated"
    static let authLoginSuccess = "auth_login_success"
    static let authLoginFailed = "auth_login_failed"
    static let authGuestModeSelected = "auth_guest_mode_selected"
    static let authLogout = "auth_logout"

    // MARK: - Setup Events
    static let setupStarted = "setup_started"
    static let setupStep1Completed = "setup_step_1_completed"
    static let setupStep2Started = "setup_step_2_started"
    static let setupStudentAdded = "setup_student_added"
    static let setupStudentAssigned = "setup_student_assigned"
    static let setupStudentReordered = "setup_student_reordered"
    static let setupCompleted = "setup_completed"
    static let setupAbandoned = "setup_abandoned"

    // MARK: - Schedule Integration Events
    static let scheduleIntegrationViewed = "schedule_integration_viewed"
    static let scheduleClassSelected = "schedule_class_selected"
    static let scheduleClassModified = "schedule_class_modified"
    static let scheduleIntegrationSkipped = "schedule_integration_skipped"

    // MARK: - Recording Events
    static let recordingSessionStarted = "recording_session_started"
    static let recordingStarted = "recording_started"
    static let recordingStopped = "recording_stopped"
    static let recordingNextSpeaker = "recording_next_speaker"
    static let recordingPreviousSpeaker = "recording_previous_speaker"
    static let recordingPlaybackStarted = "recording_playback_started"
    static let recordingPlaybackStopped = "recording_playback_stopped"
    static let recordingSessionCompleted = "recording_session_completed"
    static let recordingSessionAbandoned = "recording_session_abandoned"

    // MARK: - Timer Events
    static let timerWarningShown = "timer_warning_shown"
    static let timerBellRung = "timer_bell_rung"
    static let timerManualBellPressed = "timer_manual_bell_pressed"
    static let timerOvertimeEntered = "timer_overtime_entered"

    // MARK: - Upload Events
    static let uploadStarted = "upload_started"
    static let uploadProgressUpdated = "upload_progress_updated"
    static let uploadCompleted = "upload_completed"
    static let uploadFailed = "upload_failed"
    static let uploadRetried = "upload_retried"

    // MARK: - Processing Events
    static let processingStatusChecked = "processing_status_checked"
    static let processingCompleted = "processing_completed"

    // MARK: - Feedback List Events
    static let feedbackListViewed = "feedback_list_viewed"
    static let feedbackCardTapped = "feedback_card_tapped"
    static let feedbackListRefreshed = "feedback_list_refreshed"
    static let feedbackShareInitiated = "feedback_share_initiated"

    // MARK: - Feedback Detail Events
    static let feedbackDetailViewed = "feedback_detail_viewed"
    static let feedbackTabSwitched = "feedback_tab_switched"
    static let feedbackSectionExpanded = "feedback_section_expanded"
    static let transcriptViewed = "transcript_viewed"
    static let transcriptLinkClicked = "transcript_link_clicked"
    static let playableMomentClicked = "playable_moment_clicked"
    static let audioPlaybackStarted = "audio_playback_started"
    static let audioPlaybackStopped = "audio_playback_stopped"
    static let audioPlaybackCompleted = "audio_playback_completed"
    static let feedbackDocumentOpened = "feedback_document_opened"
    static let feedbackSharedSafari = "feedback_shared_safari"
    static let feedbackSharedSystem = "feedback_shared_system"

    // MARK: - History Events
    static let historyViewed = "history_viewed"
    static let historySearchPerformed = "history_search_performed"
    static let historyFilterApplied = "history_filter_applied"
    static let historyFilterCleared = "history_filter_cleared"
    static let historyDebateSelected = "history_debate_selected"
    static let historyDebateDeleted = "history_debate_deleted"
    static let historyDeleteConfirmed = "history_delete_confirmed"

    // MARK: - Error Events
    static let errorOccurred = "error_occurred"
    static let apiError = "api_error"
    static let networkError = "network_error"
    static let audioRecordingError = "audio_recording_error"
    static let audioPlaybackError = "audio_playback_error"
    static let documentLoadError = "document_load_error"

    // MARK: - Session Events
    static let appOpened = "app_opened"
    static let appBackgrounded = "app_backgrounded"
    static let sessionEnded = "session_ended"

    // MARK: - First Time User Experience
    static let ftueAppLaunchedFirstTime = "ftue_app_launched_first_time"
    static let ftueSetupStarted = "ftue_setup_started"
    static let ftueFirstRecordingCompleted = "ftue_first_recording_completed"
    static let ftueFirstFeedbackViewed = "ftue_first_feedback_viewed"
}
```

**Create `AnalyticsProperties.swift`:**

```swift
import Foundation

/// Property key constants for analytics events
struct AnalyticsProperties {

    // MARK: - User Properties
    static let teacherNameHash = "teacher_name_hash"
    static let deviceId = "device_id"
    static let isReturningUser = "is_returning_user"
    static let authMethod = "auth_method"
    static let userType = "user_type"
    static let totalDebatesLifetime = "total_debates_lifetime"
    static let totalRecordingsLifetime = "total_recordings_lifetime"

    // MARK: - Debate Properties
    static let debateFormat = "debate_format"
    static let studentLevel = "student_level"
    static let motionLength = "motion_length"
    static let speechTimeSeconds = "speech_time_seconds"
    static let replyTimeSeconds = "reply_time_seconds"
    static let numStudents = "num_students"

    // MARK: - Recording Properties
    static let speakerPosition = "speaker_position"
    static let recordingDuration = "recording_duration_seconds"
    static let scheduledDuration = "scheduled_duration_seconds"
    static let overtimeSeconds = "overtime_seconds"
    static let recordingNumber = "recording_number"
    static let totalRecordingsInSession = "total_recordings_in_session"
    static let recordingsCompletedSoFar = "recordings_completed_so_far"
    static let completionPercentage = "completion_percentage"

    // MARK: - Upload Properties
    static let fileSizeMB = "file_size_mb"
    static let uploadDuration = "upload_duration_seconds"
    static let networkType = "network_type"
    static let uploadSpeedMbps = "upload_speed_mbps"
    static let retryCount = "retry_count"
    static let failureReason = "failure_reason"

    // MARK: - Feedback Properties
    static let totalSpeeches = "total_speeches"
    static let readySpeeches = "ready_speeches"
    static let processingSpeeches = "processing_speeches"
    static let failedSpeeches = "failed_speeches"
    static let activeTab = "active_tab"
    static let sectionName = "section_name"
    static let playableMomentTimestamp = "playable_moment_timestamp"
    static let playableMomentIndex = "playable_moment_index"
    static let totalPlayableMoments = "total_playable_moments"

    // MARK: - Time Properties
    static let timeToLogin = "time_to_login_seconds"
    static let timeSpentOnStep1 = "time_spent_on_step_1_seconds"
    static let timeSpentOnStep2 = "time_spent_on_step_2_seconds"
    static let totalSetupTime = "total_setup_time_seconds"
    static let timeSinceSessionEnd = "time_since_session_end_minutes"
    static let timeSpentOnFeedback = "time_spent_on_feedback_seconds"
    static let sessionDuration = "session_duration_seconds"

    // MARK: - Error Properties
    static let errorType = "error_type"
    static let errorMessage = "error_message"
    static let errorCode = "error_code"
    static let screenName = "screen_name"
    static let userAction = "user_action"

    // MARK: - Schedule Integration Properties
    static let numClassesAvailable = "num_classes_available"
    static let fieldsModified = "fields_modified"
    static let usedScheduleIntegration = "used_schedule_integration"

    // MARK: - Navigation Properties
    static let numDragDropActions = "num_drag_drop_actions"
    static let numReorderActions = "num_reorder_actions"
}
```

### Step 5: Create Typed Analytics Methods

**Add to `AnalyticsService.swift`:**

```swift
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
}

// MARK: - Recording Analytics

extension AnalyticsService {
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
}
```

---

## Integration Points

### 1. AuthenticationService Integration

**Edit `/DebateFeedback/Core/Services/AuthenticationService.swift`:**

```swift
class AuthenticationService {
    // ... existing code ...

    func login(teacherName: String) async throws -> Teacher {
        // Track login initiated
        AnalyticsService.shared.logLoginInitiated()

        do {
            // ... existing login logic ...

            // Determine if returning user
            let isReturning = /* check if teacher exists in database */

            // Track success
            AnalyticsService.shared.logLoginSuccess(
                teacherName: teacherName,
                deviceId: teacher.deviceId,
                isReturning: isReturning
            )

            return teacher
        } catch {
            // Track failure
            AnalyticsService.shared.logError(
                type: "auth_error",
                message: error.localizedDescription,
                screen: "AuthView",
                action: "login"
            )
            throw error
        }
    }

    func continueAsGuest(deviceId: String) {
        AnalyticsService.shared.logGuestModeSelected(deviceId: deviceId)
        // ... existing guest logic ...
    }

    func logout() {
        AnalyticsService.shared.logLogout()
        // ... existing logout logic ...
    }
}
```

### 2. SetupViewModel Integration

**Edit `/DebateFeedback/Features/DebateSetup/SetupViewModel.swift`:**

```swift
class SetupViewModel: ObservableObject {
    // ... existing code ...

    private var setupStartTime: Date?
    private var step1CompletionTime: Date?

    func onAppear() {
        setupStartTime = Date()
        AnalyticsService.shared.logSetupStarted()
    }

    func completeStep1() {
        step1CompletionTime = Date()

        let timeSpent = setupStartTime.map { Date().timeIntervalSince($0) } ?? 0

        AnalyticsService.shared.logSetupStep1Completed(
            format: selectedFormat,
            studentLevel: studentLevel,
            motionLength: motion.count,
            speechTime: speechTimeSeconds,
            replyTime: replyTimeSeconds,
            usedSchedule: scheduleClassId != nil
        )

        AnalyticsService.shared.logSetupStep2Started()
    }

    func startDebate() {
        let totalTime = setupStartTime.map { Date().timeIntervalSince($0) } ?? 0

        AnalyticsService.shared.logSetupCompleted(
            format: selectedFormat,
            numStudents: students.count,
            totalSetupTime: totalTime
        )

        // ... existing start debate logic ...
    }

    func onDisappear() {
        if currentStep < 2 {
            AnalyticsService.shared.logSetupAbandoned(currentStep: currentStep)
        }
    }
}
```

### 3. TimerMainViewModel Integration

**Edit `/DebateFeedback/Features/DebateTimer/TimerMainViewModel.swift`:**

```swift
class TimerMainViewModel: ObservableObject {
    // ... existing code ...

    private var recordingStartTime: Date?
    private var sessionStartTime: Date?

    func onAppear() {
        sessionStartTime = Date()
    }

    func startRecording() {
        recordingStartTime = Date()

        AnalyticsService.shared.logRecordingStarted(
            speakerPosition: currentSpeaker.position,
            recordingNumber: currentSpeakerIndex + 1,
            totalRecordings: speakers.count
        )

        // ... existing recording logic ...
    }

    func stopRecording() {
        guard let startTime = recordingStartTime else { return }

        let duration = Int(Date().timeIntervalSince(startTime))
        let overtime = max(0, duration - speechTimeSeconds)

        AnalyticsService.shared.logRecordingStopped(
            speakerPosition: currentSpeaker.position,
            duration: duration,
            scheduledDuration: speechTimeSeconds,
            overtime: overtime
        )

        // ... existing stop logic ...

        // Check if session completed
        if currentSpeakerIndex == speakers.count - 1 {
            let sessionDuration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0

            AnalyticsService.shared.logRecordingSessionCompleted(
                format: session.format,
                totalRecordings: speakers.count,
                totalDuration: sessionDuration
            )
        }
    }

    func handleTimerWarning(at seconds: Int) {
        AnalyticsService.shared.logEvent(
            AnalyticsEvents.timerWarningShown,
            parameters: [
                "warning_seconds": seconds,
                AnalyticsProperties.speakerPosition: currentSpeaker.position
            ]
        )
    }

    func manualBellPressed() {
        AnalyticsService.shared.logEvent(AnalyticsEvents.timerManualBellPressed)
    }
}
```

### 4. FeedbackDetailView Integration

**Edit `/DebateFeedback/Features/Feedback/FeedbackDetailView.swift`:**

```swift
struct FeedbackDetailView: View {
    // ... existing code ...

    var body: some View {
        // ... existing view code ...
        .onAppear {
            AnalyticsService.shared.logFeedbackDetailViewed(
                speakerPosition: recording.speakerPosition,
                hasPlayableMoments: !playableMoments.isEmpty,
                playableMomentsCount: playableMoments.count
            )
        }
    }

    private func handlePlayableMomentClick(moment: PlayableMoment, index: Int) {
        AnalyticsService.shared.logPlayableMomentClicked(
            speakerPosition: recording.speakerPosition,
            timestamp: moment.timestampLabel,
            index: index,
            totalMoments: playableMoments.count
        )

        // ... existing playback logic ...
    }

    private func handleTabSwitch(to tab: FeedbackTab) {
        AnalyticsService.shared.logFeedbackTabSwitched(to: tab.rawValue)
        selectedTab = tab
    }
}
```

---

## Testing & Validation

### Debug Analytics View (Development Only)

**Create `/DebateFeedback/Debug/AnalyticsDebugView.swift`:**

```swift
#if DEBUG
import SwiftUI

struct AnalyticsDebugView: View {
    @State private var recentEvents: [String] = []

    var body: some View {
        NavigationView {
            List {
                Section("Recent Events") {
                    ForEach(recentEvents, id: \.self) { event in
                        Text(event)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Section("Test Events") {
                    Button("Test Login") {
                        AnalyticsService.shared.logLoginSuccess(
                            teacherName: "Test Teacher",
                            deviceId: "test_device",
                            isReturning: false
                        )
                    }

                    Button("Test Setup Started") {
                        AnalyticsService.shared.logSetupStarted()
                    }

                    Button("Test Recording Started") {
                        AnalyticsService.shared.logRecordingStarted(
                            speakerPosition: "Prop 1",
                            recordingNumber: 1,
                            totalRecordings: 6
                        )
                    }
                }

                Section {
                    Button("Clear Events") {
                        recentEvents.removeAll()
                    }
                }
            }
            .navigationTitle("Analytics Debug")
        }
    }
}
#endif
```

### Firebase Debug View in Console

**Enable debug mode on device:**

```bash
# Add debug flag to scheme in Xcode
# Edit Scheme → Run → Arguments
# Add argument: -FIRAnalyticsDebugEnabled

# Or run this command for simulator:
defaults write com.yourcompany.DebateFeedback FIRAnalyticsDebugEnabled -bool YES
```

**View events in Firebase:**
1. Go to Firebase Console
2. Navigate to Analytics → DebugView
3. Events appear in real-time
4. Validate event names and parameters

---

## Privacy Configuration

### Update Info.plist

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use analytics to improve the app experience. No personal data is shared.</string>

<key>ATTrackingTransparency</key>
<true/>
```

### Add Opt-Out Setting

**Create Settings view with analytics toggle:**

```swift
struct SettingsView: View {
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Analytics", isOn: $analyticsEnabled)
                    .onChange(of: analyticsEnabled) { oldValue, newValue in
                        if newValue {
                            // Re-enable analytics
                        } else {
                            AnalyticsService.shared.resetAnalyticsData()
                        }
                    }
            } header: {
                Text("Privacy")
            } footer: {
                Text("We collect anonymous usage data to improve the app. You can opt out anytime.")
            }
        }
        .navigationTitle("Settings")
    }
}
```

---

## Performance Monitoring Setup

### Firebase Performance Monitoring

**Add to Swift Package Manager:**
- Add `FirebasePerformance` package

**Initialize in App:**

```swift
import FirebasePerformance

// In DebateFeedbackApp.swift init()
Performance.sharedInstance()
```

**Track custom traces:**

```swift
extension AnalyticsService {
    func startTrace(name: String) -> Trace {
        let trace = Performance.startTrace(name: name)
        return trace
    }

    func logScreenLoadTime(screenName: String, duration: TimeInterval) {
        let trace = Performance.startTrace(name: "screen_load_\(screenName)")
        trace.stop()
        trace.setValue(Int64(duration * 1000), forMetric: "duration_ms")
    }
}
```

---

## Crashlytics Setup

### Enable Crashlytics

**Already added with Firebase package**

**Force enable in debug:**

```swift
#if DEBUG
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
#endif
```

**Log custom errors:**

```swift
extension AnalyticsService {
    func recordNonFatalError(_ error: Error, additionalInfo: [String: Any]? = nil) {
        Crashlytics.crashlytics().record(error: error)

        if let info = additionalInfo {
            for (key, value) in info {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
    }
}
```

---

## Next Steps

### Week 1-2: Foundation
- [ ] Install Firebase SDK
- [ ] Create analytics service layer
- [ ] Define event constants
- [ ] Integrate into AuthView
- [ ] Integrate into DebateSetupView
- [ ] Test with Firebase DebugView

### Week 3-4: Deep Integration
- [ ] Add recording analytics
- [ ] Add feedback viewing analytics
- [ ] Add upload/processing analytics
- [ ] Add history analytics
- [ ] Test all event flows

### Week 5: Performance & Errors
- [ ] Set up Performance Monitoring
- [ ] Set up Crashlytics
- [ ] Add error tracking throughout app
- [ ] Monitor performance metrics

### Week 6: Review & Optimize
- [ ] Review Firebase console data
- [ ] Remove unused events
- [ ] Optimize event frequency
- [ ] Document analytics spec
- [ ] Create analytics review process

---

## Resources

- Firebase iOS SDK: https://github.com/firebase/firebase-ios-sdk
- Firebase Analytics Guide: https://firebase.google.com/docs/analytics/get-started?platform=ios
- Firebase Console: https://console.firebase.google.com
- Privacy Best Practices: https://firebase.google.com/support/privacy
