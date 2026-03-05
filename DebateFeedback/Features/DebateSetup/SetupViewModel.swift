import Foundation
import Observation

@Observable
final class SetupViewModel {
    var isLoading = false
    var isSubmitting = false
    var showError = false
    var errorMessage = ""

    var studentId: Int?
    var studentName = "Debate Player"

    var streak = 0
    var xp = 0
    var dailyXp = 0
    var dailyGoal = 200
    var gems = 0
    var level = 1
    var nextLevelXp = 250

    var leagueTier = "BRONZE"
    var leagueRank = 1
    var leagueTotalMembers = 1

    var nextDrillType = "HOOK_HERO"
    var nextDrillPrompt = ""
    var maxDurationSeconds = 60

    var isRecording = false
    var recordingSeconds = 0

    var showResult = false
    var lastScore: Int?
    var lastXpAwarded: Int?
    var lastPraise = ""
    var lastCritique = ""

    private let apiClient: APIClientProtocol
    private let recordingService: AudioRecordingServicing

    @ObservationIgnored private var initialized = false
    @ObservationIgnored private var recordingClockTask: Task<Void, Never>?

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        recordingService: AudioRecordingServicing = AudioRecordingService()
    ) {
        self.apiClient = apiClient
        self.recordingService = recordingService
    }

    deinit {
        recordingClockTask?.cancel()
    }

    var ctaTitle: String {
        if isSubmitting {
            return "Scoring..."
        }
        if isRecording {
            return "Stop & Score"
        }
        return "Start Daily Drill"
    }

    var recordingProgress: Double {
        guard maxDurationSeconds > 0 else { return 0 }
        return min(1.0, Double(recordingSeconds) / Double(maxDurationSeconds))
    }

    @MainActor
    func initializeIfNeeded() async {
        guard !initialized else { return }
        initialized = true
        await bootstrapSession()
    }

    @MainActor
    func handlePrimaryAction() {
        if isSubmitting { return }

        Task {
            if isRecording {
                await stopAndSubmit()
            } else {
                await startRecording()
            }
        }
    }

    @MainActor
    private func bootstrapSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = await recordingService.requestPermission()

            let response: CoachIdentifyResponse = try await apiClient.request(
                endpoint: .identifyCoach,
                body: CoachIdentifyRequest(
                    deviceId: setupDeviceId(),
                    name: nil,
                    parentEmail: nil
                )
            )

            applyIdentityResponse(response)

        } catch {
            setError(error)
        }
    }

    @MainActor
    private func startRecording() async {
        do {
            let granted = await recordingService.requestPermission()
            guard granted else {
                throw RecordingError.permissionDenied
            }

            let safeName = studentName.replacingOccurrences(of: " ", with: "_")
            _ = try recordingService.startRecording(
                debateId: "daily_drill",
                speakerName: safeName,
                position: nextDrillType
            )

            recordingSeconds = 0
            isRecording = true
            startClock()

        } catch {
            setError(error)
        }
    }

    @MainActor
    private func stopAndSubmit() async {
        guard isRecording else { return }

        isRecording = false
        recordingClockTask?.cancel()
        recordingClockTask = nil

        guard let stopped = recordingService.stopRecording() else {
            setError(NetworkError.uploadFailed(reason: "No recording to submit"))
            return
        }

        let durationSeconds = max(1, Int(round(stopped.duration)))
        await submitDrill(fileURL: stopped.url, durationSeconds: durationSeconds)
    }

    @MainActor
    private func submitDrill(fileURL: URL, durationSeconds: Int) async {
        guard let studentId else {
            setError(NetworkError.uploadFailed(reason: "Missing student session"))
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await apiClient.uploadDrillAttempt(
                fileURL: fileURL,
                metadata: [
                    "student_id": studentId,
                    "drill_type": nextDrillType,
                    "prompt_given": nextDrillPrompt,
                    "duration_seconds": durationSeconds
                ],
                progressHandler: { _ in }
            )

            applyAttemptResponse(response)
            HapticManager.shared.success()

        } catch {
            setError(error)
        }
    }

    private func startClock() {
        recordingClockTask?.cancel()
        recordingClockTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard self.isRecording else { return }
                    self.recordingSeconds += 1

                    if self.recordingSeconds >= self.maxDurationSeconds {
                        Task {
                            await self.stopAndSubmit()
                        }
                    }
                }
            }
        }
    }

    private func setupDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.deviceId), !existing.isEmpty {
            return existing
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Constants.UserDefaultsKeys.deviceId)
        return generated
    }

    private func applyIdentityResponse(_ response: CoachIdentifyResponse) {
        studentId = response.student.id
        studentName = response.student.name

        applyHomeState(response.homeState)

        if let league = response.league {
            applyLeague(league)
        }
    }

    private func applyAttemptResponse(_ response: DrillAttemptResponse) {
        lastScore = response.score
        lastXpAwarded = response.xpAwarded
        lastPraise = response.feedback.praise
        lastCritique = response.feedback.critique
        showResult = true

        applyProgress(response.progress)
        applyHomeState(response.homeState)
        applyLeague(response.league)
    }

    private func applyProgress(_ progress: CoachProgress) {
        xp = progress.xp
        streak = progress.streak
        gems = progress.gems
        leagueTier = progress.leagueTier
        dailyXp = progress.dailyXp
        dailyGoal = progress.dailyGoal
        level = progress.level
        nextLevelXp = progress.nextLevelXp
    }

    private func applyHomeState(_ homeState: CoachHomeState) {
        nextDrillType = homeState.nextDrillType
        nextDrillPrompt = homeState.nextDrillPrompt
        maxDurationSeconds = homeState.nextDrillMaxDurationSeconds
        applyProgress(homeState)
    }

    private func applyLeague(_ league: LeagueSnapshot) {
        leagueTier = league.tier
        leagueRank = league.myRank
        leagueTotalMembers = max(1, league.totalMembers)
    }

    private func setError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
