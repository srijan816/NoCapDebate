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
