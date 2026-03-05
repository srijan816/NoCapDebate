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
