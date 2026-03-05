//
//  APIClient.swift
//  DebateFeedback
//
//

import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var authToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.requestTimeout
        config.timeoutIntervalForResource = Constants.API.uploadTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Generic Request Methods

    func request<T: Decodable>(
        endpoint: Endpoint,
        body: Encodable? = nil
    ) async throws -> T {
        #if DEBUG
        if Constants.API.useMockData {
            return try await mockResponse(for: endpoint)
        }
        #endif

        guard let url = endpoint.url() else {
            AnalyticsService.shared.logError(
                type: "api_error",
                message: "Invalid URL for endpoint: \(endpoint)",
                code: "invalid_url",
                screen: "APIClient",
                action: "request"
            )
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.encodingError
            }
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                AnalyticsService.shared.logError(
                    type: "api_error",
                    message: "Invalid HTTP response",
                    code: "invalid_response",
                    screen: "APIClient",
                    action: "request:\(endpoint)"
                )
                throw NetworkError.unknown(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                AnalyticsService.shared.logError(
                    type: "api_error",
                    message: "HTTP error: \(httpResponse.statusCode)",
                    code: "\(httpResponse.statusCode)",
                    screen: "APIClient",
                    action: "request:\(endpoint)"
                )
                if httpResponse.statusCode == 401 {
                    throw NetworkError.unauthorized
                } else if httpResponse.statusCode == 404 {
                    throw NetworkError.notFound
                }
                throw NetworkError.serverError(statusCode: httpResponse.statusCode, payload: data)
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try decoder.decode(T.self, from: data)
                return decoded
            } catch {
                // DIAGNOSTIC: Print raw response and decoding error
                print("========== DECODING ERROR DIAGNOSTICS ==========")
                print("❌ Failed to decode response as: \(T.self)")
                print("📦 Raw response data (\(data.count) bytes):")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString.prefix(2000)) // Print first 2000 chars
                }
                print("🔥 Decoding error: \(error)")
                print("================================================")

                AnalyticsService.shared.logError(
                    type: "api_error",
                    message: "Failed to decode \(T.self): \(error.localizedDescription)",
                    code: "decoding_error",
                    screen: "APIClient",
                    action: "request:\(endpoint)"
                )
                throw NetworkError.decodingError
            }

        } catch let error as NetworkError {
            throw error
        } catch {
            AnalyticsService.shared.logError(
                type: "network_error",
                message: "Network request failed: \(error.localizedDescription)",
                code: "unknown",
                screen: "APIClient",
                action: "request:\(endpoint)"
            )
            throw NetworkError.unknown(error)
        }
    }

    // MARK: - Upload with Progress

    func upload(
        endpoint: Endpoint,
        fileURL: URL,
        metadata: [String: Any],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> UploadResponse {
        #if DEBUG
        if Constants.API.useMockData {
            for checkpoint in [0.1, 0.5, 1.0] {
                await MainActor.run {
                    progressHandler(checkpoint)
                }
            }
            return UploadResponse(
                speechId: UUID().uuidString,
                status: "uploaded",
                processingStarted: true
            )
        }
        #endif

        await MainActor.run {
            progressHandler(0.05)
        }

        do {
            let initiation = try await initiateSignedUpload(fileURL: fileURL, metadata: metadata)
            await MainActor.run {
                progressHandler(0.2)
            }

            try await uploadToSignedURL(
                uploadURLString: initiation.uploadURL,
                fileURL: fileURL,
                contentType: initiation.headers?.contentType ?? "audio/mp4"
            )
            await MainActor.run {
                progressHandler(0.85)
            }

            let completion = try await completeSignedUpload(
                initiation: initiation,
                metadata: metadata,
                fileURL: fileURL
            )
            await MainActor.run {
                progressHandler(1.0)
            }
            return completion
        } catch let error as NetworkError {
            if shouldFallbackToLegacyUpload(error) {
                return try await uploadLegacyMultipart(
                    endpoint: endpoint,
                    fileURL: fileURL,
                    metadata: metadata,
                    progressHandler: progressHandler
                )
            }
            throw error
        } catch {
            throw NetworkError.uploadFailed(reason: error.localizedDescription)
        }
    }

    func uploadDrillAttempt(
        fileURL: URL,
        metadata: [String: Any],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> DrillAttemptResponse {
        #if DEBUG
        if Constants.API.useMockData {
            for checkpoint in [0.2, 0.6, 1.0] {
                await MainActor.run {
                    progressHandler(checkpoint)
                }
            }
            return DrillAttemptResponse.mock
        }
        #endif

        return try await uploadMultipartAndDecode(
            endpoint: .uploadDrillAttempt,
            fileURL: fileURL,
            metadata: metadata,
            progressHandler: progressHandler,
            as: DrillAttemptResponse.self
        )
    }

    private func initiateSignedUpload(
        fileURL: URL,
        metadata: [String: Any]
    ) async throws -> UploadInitiateResponse {
        guard
            let debateId = metadata["debate_id"] as? String,
            let speakerName = metadata["speaker_name"] as? String,
            let speakerPosition = metadata["speaker_position"] as? String
        else {
            throw NetworkError.uploadFailed(reason: "Missing required upload metadata")
        }

        let fileExt = fileURL.pathExtension.isEmpty ? "m4a" : fileURL.pathExtension
        let requestBody = UploadInitiateRequest(
            debateId: debateId,
            speakerName: speakerName,
            speakerPosition: speakerPosition,
            fileExtension: fileExt,
            contentType: "audio/\(fileExt == "m4a" ? "mp4" : fileExt)"
        )

        return try await request(endpoint: .initiateUpload, body: requestBody)
    }

    private func uploadToSignedURL(
        uploadURLString: String,
        fileURL: URL,
        contentType: String
    ) async throws {
        guard let uploadURL = URL(string: uploadURLString) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.upload(for: request, fromFile: fileURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.uploadFailed(reason: "Invalid upload response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, payload: nil)
        }
    }

    private func completeSignedUpload(
        initiation: UploadInitiateResponse,
        metadata: [String: Any],
        fileURL: URL
    ) async throws -> UploadResponse {
        guard
            let debateId = metadata["debate_id"] as? String,
            let speakerName = metadata["speaker_name"] as? String,
            let speakerPosition = metadata["speaker_position"] as? String
        else {
            throw NetworkError.uploadFailed(reason: "Missing required completion metadata")
        }

        let duration = metadata["duration_seconds"] as? Int ?? 0
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes?[.size] as? NSNumber

        let requestBody = UploadCompleteRequest(
            debateId: debateId,
            speakerName: speakerName,
            speakerPosition: speakerPosition,
            durationSeconds: max(1, duration),
            fileSizeBytes: fileSize?.intValue,
            audioFilePath: initiation.audioFilePath
        )

        return try await request(endpoint: .completeUpload, body: requestBody)
    }

    private func shouldFallbackToLegacyUpload(_ error: NetworkError) -> Bool {
        switch error {
        case .notFound:
            return true
        case .serverError(let statusCode, _):
            return statusCode == 404 || statusCode == 501 || statusCode == 503
        default:
            return false
        }
    }

    private func uploadLegacyMultipart(
        endpoint: Endpoint,
        fileURL: URL,
        metadata: [String: Any],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> UploadResponse {
        try await uploadMultipartAndDecode(
            endpoint: endpoint,
            fileURL: fileURL,
            metadata: metadata,
            progressHandler: progressHandler,
            as: UploadResponse.self
        )
    }

    private func uploadMultipartAndDecode<T: Decodable>(
        endpoint: Endpoint,
        fileURL: URL,
        metadata: [String: Any],
        progressHandler: @escaping (Double) -> Void,
        as: T.Type
    ) async throws -> T {
        guard let url = endpoint.url() else {
            AnalyticsService.shared.logError(
                type: "upload_error",
                message: "Invalid URL for upload endpoint: \(endpoint)",
                code: "invalid_url",
                screen: "APIClient",
                action: "upload"
            )
            throw NetworkError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let multipartFileURL: URL
        do {
            multipartFileURL = try createMultipartTempFile(
                boundary: boundary,
                fileURL: fileURL,
                metadata: metadata
            )
        } catch {
            throw NetworkError.uploadFailed(reason: "Failed to prepare upload body")
        }
        defer {
            try? FileManager.default.removeItem(at: multipartFileURL)
        }

        do {
            await MainActor.run {
                progressHandler(0.15)
            }

            let (data, response) = try await session.upload(for: request, fromFile: multipartFileURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                AnalyticsService.shared.logError(
                    type: "upload_error",
                    message: "Invalid HTTP response during upload",
                    code: "invalid_response",
                    screen: "APIClient",
                    action: "upload:\(endpoint)"
                )
                throw NetworkError.unknown(NSError(domain: "Invalid response", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                AnalyticsService.shared.logError(
                    type: "upload_error",
                    message: "Upload failed with HTTP \(httpResponse.statusCode)",
                    code: "\(httpResponse.statusCode)",
                    screen: "APIClient",
                    action: "upload:\(endpoint)"
                )
                throw NetworkError.serverError(statusCode: httpResponse.statusCode, payload: data)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(T.self, from: data)
            await MainActor.run {
                progressHandler(1.0)
            }
            return decoded

        } catch let error as NetworkError {
            throw error
        } catch {
            AnalyticsService.shared.logError(
                type: "upload_error",
                message: "Upload failed: \(error.localizedDescription)",
                code: "upload_failed",
                screen: "APIClient",
                action: "upload:\(endpoint)"
            )
            throw NetworkError.uploadFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Multipart Form Data Helper

    private func createMultipartTempFile(
        boundary: String,
        fileURL: URL,
        metadata: [String: Any]
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).multipart")

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: tempURL)
        defer {
            try? outputHandle.close()
        }

        func writeString(_ value: String) throws {
            if let data = value.data(using: .utf8) {
                try outputHandle.write(contentsOf: data)
            }
        }

        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            try writeString("--\(boundary)\r\n")
            try writeString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            try writeString("\(value)\r\n")
        }

        try writeString("--\(boundary)\r\n")
        try writeString("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        try writeString("Content-Type: audio/m4a\r\n\r\n")

        let inputHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? inputHandle.close()
        }

        while true {
            let chunk = try inputHandle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty {
                break
            }
            try outputHandle.write(contentsOf: chunk)
        }

        try writeString("\r\n")
        try writeString("--\(boundary)--\r\n")
        return tempURL
    }

    // MARK: - Mock Responses (for development without backend)

    #if DEBUG
    private func mockResponse<T: Decodable>(for endpoint: Endpoint) async throws -> T {
        switch endpoint {
        case .identifyCoach:
            let response = CoachIdentifyResponse(
                student: CoachStudent(id: 1, name: "Mock Player", xp: 420, streak: 5, gems: 18, leagueTier: "SILVER", parentEmail: nil),
                homeState: CoachHomeState(
                    studentId: 1,
                    xp: 420,
                    streak: 5,
                    gems: 18,
                    leagueTier: "SILVER",
                    dailyXp: 120,
                    dailyGoal: 200,
                    level: 2,
                    nextLevelXp: 1000,
                    nextDrillType: "HOOK_HERO",
                    nextDrillPrompt: "This house would make financial literacy mandatory in schools.",
                    nextDrillMaxDurationSeconds: 60
                ),
                league: LeagueSnapshot(
                    tier: "SILVER",
                    cohortId: UUID().uuidString,
                    weekStart: "2026-03-01",
                    weekEnd: "2026-03-08",
                    myRank: 7,
                    myWeeklyXp: 320,
                    totalMembers: 30,
                    top: []
                )
            )
            return response as! T

        case .getCoachHomeState:
            let response = CoachHomeResponse(
                homeState: CoachHomeState(
                    studentId: 1,
                    xp: 420,
                    streak: 5,
                    gems: 18,
                    leagueTier: "SILVER",
                    dailyXp: 120,
                    dailyGoal: 200,
                    level: 2,
                    nextLevelXp: 1000,
                    nextDrillType: "HOOK_HERO",
                    nextDrillPrompt: "This house would make financial literacy mandatory in schools.",
                    nextDrillMaxDurationSeconds: 60
                ),
                league: LeagueSnapshot(
                    tier: "SILVER",
                    cohortId: UUID().uuidString,
                    weekStart: "2026-03-01",
                    weekEnd: "2026-03-08",
                    myRank: 7,
                    myWeeklyXp: 320,
                    totalMembers: 30,
                    top: []
                )
            )
            return response as! T

        case .getNextDrill:
            let response = NextDrillResponse(
                drillType: "HOOK_HERO",
                prompt: "This house would replace most exams with project-based assessments.",
                maxDurationSeconds: 60
            )
            return response as! T

        case .getLeagueCurrent:
            let response = LeagueCurrentResponse(
                league: LeagueSnapshot(
                    tier: "SILVER",
                    cohortId: UUID().uuidString,
                    weekStart: "2026-03-01",
                    weekEnd: "2026-03-08",
                    myRank: 7,
                    myWeeklyXp: 320,
                    totalMembers: 30,
                    top: []
                )
            )
            return response as! T

        case .login:
            let response = LoginResponse(
                token: "mock_token_\(UUID().uuidString)",
                teacher: TeacherResponse(
                    id: UUID().uuidString,
                    name: "Mock Teacher",
                    isAdmin: false
                )
            )
            return response as! T

        case .getCurrentSchedule(_, _, let classId):
            let primaryClassId = classId ?? UUID().uuidString
            let mockStudents = [
                StudentResponse(id: UUID().uuidString, name: "Alice Smith", level: "secondary", grade: "9"),
                StudentResponse(id: UUID().uuidString, name: "Bob Johnson", level: "secondary", grade: "10"),
                StudentResponse(id: UUID().uuidString, name: "Carol White", level: "secondary", grade: "9")
            ]
            let response = ScheduleResponse(
                classId: primaryClassId,
                students: mockStudents,
                suggestedMotion: "This house believes that social media does more harm than good",
                format: "WSDC",
                speechTime: 300,
                alternatives: [
                    ScheduleAlternative(
                        classId: primaryClassId + "-ALT1",
                        startTime: "18:00",
                        startDateTime: "2025-11-08T18:00:00.000Z" // Friday 6:00 PM
                    ),
                    ScheduleAlternative(
                        classId: primaryClassId + "-ALT2",
                        startTime: "20:00",
                        startDateTime: "2025-11-08T20:00:00.000Z" // Friday 8:00 PM
                    )
                ],
                startDateTime: "2025-11-08T16:30:00.000Z", // Friday 4:30 PM for the main class
                availableClasses: [
                    ScheduleResponse.ClassInfo(
                        classId: primaryClassId,
                        scheduleId: "sched-001",
                        source: "teacher",
                        displayLabel: "Friday 4:30 PM",
                        dayOfWeek: 5,
                        dayName: "Friday",
                        startTime: "16:30",
                        endTime: "18:00",
                        format: "WSDC",
                        speechTime: 300,
                        suggestedMotion: "This house believes that social media does more harm than good",
                        students: mockStudents
                    ),
                    ScheduleResponse.ClassInfo(
                        classId: primaryClassId + "-ALT1",
                        scheduleId: "sched-002",
                        source: "teacher",
                        displayLabel: "Friday 6:00 PM",
                        dayOfWeek: 5,
                        dayName: "Friday",
                        startTime: "18:00",
                        endTime: "19:30",
                        format: "BP",
                        speechTime: 420,
                        suggestedMotion: "This house would ban single-use plastics",
                        students: mockStudents.shuffled()
                    ),
                    ScheduleResponse.ClassInfo(
                        classId: primaryClassId + "-SAT",
                        scheduleId: "sched-003",
                        source: "teacher",
                        displayLabel: "Saturday 1:00 PM",
                        dayOfWeek: 6,
                        dayName: "Saturday",
                        startTime: "13:00",
                        endTime: "14:30",
                        format: "AP",
                        speechTime: 360,
                        suggestedMotion: nil,
                        students: mockStudents
                    )
                ]
            )
            return response as! T

        case .createDebate:
            let uuid = UUID().uuidString
            let response = CreateDebateResponse(debateId: uuid)
            return response as! T

        case .getSpeechStatus:
            let response = SpeechStatusResponse(
                status: "complete",
                feedbackUrl: "https://api.genalphai.com/feedback/view/mock_speech",
                errorMessage: nil,
                transcriptionStatus: "completed",
                transcriptionError: nil,
                feedbackStatus: "completed",
                feedbackError: nil,
                transcriptUrl: "https://docs.google.com/document/d/mock_transcript_id",
                transcriptText: "Mock transcript body"
            )
            return response as! T

        case .getDebateHistory:
            let response = DebateHistoryResponse(debates: [])
            return response as! T

        default:
            throw NetworkError.unknown(NSError(domain: "Mock not implemented", code: -1))
        }
    }
    #endif
}

extension APIClient: APIClientProtocol {}

// MARK: - Response Models

struct CoachIdentifyRequest: Codable {
    let deviceId: String
    let name: String?
    let parentEmail: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case name
        case parentEmail = "parent_email"
    }
}

struct CoachStudent: Codable {
    let id: Int
    let name: String
    let xp: Int
    let streak: Int
    let gems: Int
    let leagueTier: String
    let parentEmail: String?

    enum CodingKeys: String, CodingKey {
        case id, name, xp, streak, gems
        case leagueTier = "league_tier"
        case parentEmail = "parent_email"
    }
}

struct CoachProgress: Codable {
    let studentId: Int
    let xp: Int
    let streak: Int
    let gems: Int
    let leagueTier: String
    let dailyXp: Int
    let dailyGoal: Int
    let level: Int
    let nextLevelXp: Int

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case xp
        case streak
        case gems
        case leagueTier = "league_tier"
        case dailyXp = "daily_xp"
        case dailyGoal = "daily_goal"
        case level
        case nextLevelXp = "next_level_xp"
    }
}

struct CoachHomeState: Codable {
    let studentId: Int
    let xp: Int
    let streak: Int
    let gems: Int
    let leagueTier: String
    let dailyXp: Int
    let dailyGoal: Int
    let level: Int
    let nextLevelXp: Int
    let nextDrillType: String
    let nextDrillPrompt: String
    let nextDrillMaxDurationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case xp
        case streak
        case gems
        case leagueTier = "league_tier"
        case dailyXp = "daily_xp"
        case dailyGoal = "daily_goal"
        case level
        case nextLevelXp = "next_level_xp"
        case nextDrillType = "next_drill_type"
        case nextDrillPrompt = "next_drill_prompt"
        case nextDrillMaxDurationSeconds = "next_drill_max_duration_seconds"
    }
}

struct LeagueEntry: Codable {
    let studentId: Int
    let name: String
    let weeklyXp: Int
    let rank: Int

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case name
        case weeklyXp = "weekly_xp"
        case rank
    }
}

struct LeagueSnapshot: Codable {
    let tier: String
    let cohortId: String
    let weekStart: String
    let weekEnd: String
    let myRank: Int
    let myWeeklyXp: Int
    let totalMembers: Int
    let top: [LeagueEntry]

    enum CodingKeys: String, CodingKey {
        case tier
        case cohortId = "cohort_id"
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case myRank = "my_rank"
        case myWeeklyXp = "my_weekly_xp"
        case totalMembers = "total_members"
        case top
    }
}

struct CoachIdentifyResponse: Codable {
    let student: CoachStudent
    let homeState: CoachHomeState
    let league: LeagueSnapshot?

    enum CodingKeys: String, CodingKey {
        case student
        case homeState = "home_state"
        case league
    }
}

struct CoachHomeResponse: Codable {
    let homeState: CoachHomeState
    let league: LeagueSnapshot

    enum CodingKeys: String, CodingKey {
        case homeState = "home_state"
        case league
    }
}

struct NextDrillResponse: Codable {
    let drillType: String
    let prompt: String
    let maxDurationSeconds: Int

    enum CodingKeys: String, CodingKey {
        case drillType = "drill_type"
        case prompt
        case maxDurationSeconds = "max_duration_seconds"
    }
}

struct LeagueCurrentResponse: Codable {
    let league: LeagueSnapshot
}

struct DrillFeedbackPayload: Codable {
    let praise: String
    let critique: String
}

struct DrillAttemptResponse: Codable {
    let attemptId: String
    let drillType: String
    let score: Int
    let xpAwarded: Int
    let feedback: DrillFeedbackPayload
    let transcriptText: String?
    let latencyMs: Int?
    let progress: CoachProgress
    let homeState: CoachHomeState
    let league: LeagueSnapshot

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case drillType = "drill_type"
        case score
        case xpAwarded = "xp_awarded"
        case feedback
        case transcriptText = "transcript_text"
        case latencyMs = "latency_ms"
        case progress
        case homeState = "home_state"
        case league
    }
}

extension DrillAttemptResponse {
    static let mock = DrillAttemptResponse(
        attemptId: UUID().uuidString,
        drillType: "HOOK_HERO",
        score: 84,
        xpAwarded: 101,
        feedback: DrillFeedbackPayload(
            praise: "Your opening hook lands quickly and builds interest in the issue.",
            critique: "Add one concrete image or statistic to make your first line even more memorable."
        ),
        transcriptText: "Mock transcript",
        latencyMs: 2200,
        progress: CoachProgress(
            studentId: 1,
            xp: 521,
            streak: 6,
            gems: 19,
            leagueTier: "SILVER",
            dailyXp: 221,
            dailyGoal: 200,
            level: 2,
            nextLevelXp: 1000
        ),
        homeState: CoachHomeState(
            studentId: 1,
            xp: 521,
            streak: 6,
            gems: 19,
            leagueTier: "SILVER",
            dailyXp: 221,
            dailyGoal: 200,
            level: 2,
            nextLevelXp: 1000,
            nextDrillType: "REBUTTAL_MACHINE_GUN",
            nextDrillPrompt: "Social media does more harm than good for teenagers.",
            nextDrillMaxDurationSeconds: 90
        ),
        league: LeagueSnapshot(
            tier: "SILVER",
            cohortId: UUID().uuidString,
            weekStart: "2026-03-01",
            weekEnd: "2026-03-08",
            myRank: 6,
            myWeeklyXp: 421,
            totalMembers: 30,
            top: []
        )
    )
}

struct LoginResponse: Codable {
    let token: String
    let teacher: TeacherResponse
}

struct TeacherResponse: Codable {
    let id: String
    let name: String
    let isAdmin: Bool
}

struct ScheduleResponse: Codable {
    let classId: String
    let students: [StudentResponse]
    let suggestedMotion: String?
    let format: String
    let speechTime: Int
    let alternatives: [ScheduleAlternative]?
    let startDateTime: String? // Full ISO8601 datetime for the main class
    let availableClasses: [ClassInfo]?

    /// Returns formatted display string for the main class
    var classDisplayString: String {
        let dayTime = formattedDayTime()
        if dayTime == classId {
            return classId
        }
        return "\(dayTime) - \(classId)"
    }

    /// Returns just day and time for the main class
    var classDayTimeString: String {
        formattedDayTime()
    }

    private func formattedDayTime() -> String {
        ClassScheduleFormatter.dayTimeString(
            classId: classId,
            startDateTime: startDateTime,
            fallbackStartTime: nil
        ) ?? classId
    }

    struct ClassInfo: Codable {
        let classId: String
        let scheduleId: String?
        let source: String?
        let displayLabel: String?
        let dayOfWeek: Int?
        let dayName: String?
        let startTime: String?
        let endTime: String?
        let format: String?
        let speechTime: Int?
        let suggestedMotion: String?
        let students: [StudentResponse]

        var dayTimeString: String? {
            if let displayLabel, !displayLabel.isEmpty {
                return displayLabel
            }

            return ClassScheduleFormatter.dayTimeString(
                classId: classId,
                startDateTime: nil,
                fallbackStartTime: startTime,
                explicitDayName: dayName
            )
        }

        var displayTitle: String {
            dayTimeString ?? classId
        }

        var displaySubtitle: String? {
            guard dayTimeString != nil else { return nil }
            return classId
        }

        static func primaryFallback(from response: ScheduleResponse) -> ClassInfo {
            ClassInfo(
                classId: response.classId,
                scheduleId: nil,
                source: "primary",
                displayLabel: response.classDayTimeString == response.classId ? nil : response.classDayTimeString,
                dayOfWeek: nil,
                dayName: nil,
                startTime: nil,
                endTime: nil,
                format: response.format,
                speechTime: response.speechTime,
                suggestedMotion: response.suggestedMotion,
                students: response.students
            )
        }
    }
}

struct ScheduleAlternative: Codable, Hashable {
    let classId: String
    let startTime: String // Keep for backward compatibility
    let startDateTime: String? // Full ISO8601 datetime from backend

    /// Returns formatted display string like "Friday 4:30 PM - BEG-FRI-1430"
    var displayString: String {
        let dayTimeString = formattedDayTime()
        if dayTimeString == classId {
            return classId
        }
        return "\(dayTimeString) - \(classId)"
    }

    /// Returns just the day and time portion like "Friday 4:30 PM"
    var dayTimeString: String {
        formattedDayTime()
    }

    private func formattedDayTime() -> String {
        ClassScheduleFormatter.dayTimeString(
            classId: classId,
            startDateTime: startDateTime,
            fallbackStartTime: startTime
        ) ?? classId
    }
}

// MARK: - Schedule Formatting Helpers

fileprivate enum ClassScheduleFormatter {
    static func dayTimeString(
        classId: String,
        startDateTime: String?,
        fallbackStartTime: String?,
        explicitDayName: String? = nil
    ) -> String? {
        if let startDateTime,
           let date = Date.from(iso8601String: startDateTime) {
            return formattedDayTime(from: date)
        }

        let day = explicitDayName ?? dayName(fromClassId: classId)
        let time = formattedTime(fromExplicit: fallbackStartTime) ?? formattedTime(fromClassId: classId)

        switch (day, time) {
        case let (day?, time?):
            return "\(day) \(time)"
        case let (day?, nil):
            return day
        case let (nil, time?):
            return time
        default:
            return nil
        }
    }

    private static func formattedDayTime(from date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let day = dayFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let time = timeFormatter.string(from: date)

        return "\(day) \(time)"
    }

    private static func dayName(fromClassId classId: String) -> String? {
        let components = classId.split(separator: "-")
        for component in components {
            let upper = component.uppercased()
            if let fullName = dayLookup[upper] {
                return fullName
            }
        }
        return nil
    }

    private static func formattedTime(fromExplicit explicit: String?) -> String? {
        guard let explicit, !explicit.isEmpty else { return nil }

        if explicit.contains(":") {
            let parts = explicit.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1]) {
                return formattedTime(hour: hour, minute: minute)
            }
        }

        if explicit.count == 4,
           let hour = Int(explicit.prefix(2)),
           let minute = Int(explicit.suffix(2)) {
            return formattedTime(hour: hour, minute: minute)
        }

        return nil
    }

    private static func formattedTime(fromClassId classId: String) -> String? {
        guard let lastComponent = classId.split(separator: "-").last else { return nil }
        let raw = String(lastComponent)
        guard raw.count == 4,
              let hour = Int(raw.prefix(2)),
              let minute = Int(raw.suffix(2)) else {
            return nil
        }
        return formattedTime(hour: hour, minute: minute)
    }

    private static func formattedTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let normalizedHour: Int
        if hour == 0 {
            normalizedHour = 12
        } else if hour > 12 {
            normalizedHour = hour - 12
        } else {
            normalizedHour = hour
        }
        return String(format: "%d:%02d %@", normalizedHour, minute, period)
    }

    private static let dayLookup: [String: String] = [
        "MON": "Monday",
        "TUE": "Tuesday",
        "WED": "Wednesday",
        "THU": "Thursday",
        "FRI": "Friday",
        "SAT": "Saturday",
        "SUN": "Sunday"
    ]
}

struct StudentResponse: Codable {
    let id: String
    let name: String
    let level: String
    let grade: String?
}

struct CreateDebateRequest: Codable {
    let motion: String
    let format: String
    let studentLevel: String
    let speechTimeSeconds: Int
    let teams: TeamsData
    let classId: String?
    let scheduleId: String?

    enum CodingKeys: String, CodingKey {
        case motion, format, teams
        case studentLevel = "student_level"
        case speechTimeSeconds = "speech_time_seconds"
        case classId = "class_id"
        case scheduleId = "schedule_id"
    }
}

struct TeamsData: Codable {
    var prop: [StudentData]?
    var opp: [StudentData]?
    var og: [StudentData]?
    var oo: [StudentData]?
    var cg: [StudentData]?
    var co: [StudentData]?
}

struct StudentData: Codable {
    let name: String
    let position: String
}

struct CreateDebateResponse: Codable {
    let debateId: String
}

struct UploadInitiateRequest: Codable {
    let debateId: String
    let speakerName: String
    let speakerPosition: String
    let fileExtension: String
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case debateId = "debate_id"
        case speakerName = "speaker_name"
        case speakerPosition = "speaker_position"
        case fileExtension = "file_extension"
        case contentType = "content_type"
    }
}

struct UploadInitiateHeaders: Codable {
    let contentType: String?

    enum CodingKeys: String, CodingKey {
        case contentType = "Content-Type"
    }
}

struct UploadInitiateResponse: Codable {
    let uploadURL: String
    let audioFilePath: String
    let expiresAt: String?
    let expiresInSeconds: Int?
    let headers: UploadInitiateHeaders?

    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case audioFilePath = "audio_file_path"
        case expiresAt = "expires_at"
        case expiresInSeconds = "expires_in_seconds"
        case headers
    }
}

struct UploadCompleteRequest: Codable {
    let debateId: String
    let speakerName: String
    let speakerPosition: String
    let durationSeconds: Int
    let fileSizeBytes: Int?
    let audioFilePath: String

    enum CodingKeys: String, CodingKey {
        case debateId = "debate_id"
        case speakerName = "speaker_name"
        case speakerPosition = "speaker_position"
        case durationSeconds = "duration_seconds"
        case fileSizeBytes = "file_size_bytes"
        case audioFilePath = "audio_file_path"
    }
}

struct UploadResponse: Codable {
    let speechId: String
    let status: String
    let processingStarted: Bool
}

struct SpeechStatusResponse: Codable {
    let status: String
    let feedbackUrl: String?
    let errorMessage: String?
    let transcriptionStatus: String?
    let transcriptionError: String?
    let feedbackStatus: String?
    let feedbackError: String?
    let transcriptUrl: String?
    let transcriptText: String?
}

struct FeedbackContentResponse: Codable {
    let speechId: String
    let scores: [String: RubricScore]?
    let qualitativeFeedback: QualitativeFeedback?
    let feedbackText: String?
    let sections: [FeedbackSection]?
    let playableMoments: [PlayableMoment]?
    let audioUrl: String?

    struct QualitativeFeedback: Codable {
        let feedbackText: String?
    }

    struct FeedbackSection: Codable {
        let title: String
        let content: String
    }

    // Note: No explicit CodingKeys needed - decoder uses .convertFromSnakeCase
    // which automatically converts:
    //   speech_id -> speechId
    //   qualitative_feedback -> qualitativeFeedback
    //   feedback_text -> feedbackText
    //   playable_moments -> playableMoments
    //   audio_url -> audioUrl
    
    /// Helper to get feedback text from both top-level and nested payloads.
    var resolvedFeedbackText: String {
        feedbackText ?? qualitativeFeedback?.feedbackText ?? ""
    }
}

struct DebateHistoryResponse: Codable {
    let debates: [DebateHistoryItem]
}

struct DebateHistoryItem: Codable {
    let debateId: String
    let motion: String
    let date: String
    let speeches: [SpeechHistoryItem]
}

struct SpeechHistoryItem: Codable {
    let speakerName: String
    let feedbackUrl: String?
    let scores: [String: RubricScore]?
}

enum RubricScore: Codable, Hashable, CustomStringConvertible {
    case number(Double)
    case notApplicable
    case text(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }

        if let string = try? container.decode(String.self) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper == "NA" || upper == "N/A" {
                self = .notApplicable
                return
            }
            if let parsed = Double(trimmed) {
                self = .number(parsed)
                return
            }
            self = .text(trimmed)
            return
        }

        self = .text("")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .notApplicable:
            try container.encode("NA")
        case .text(let value):
            try container.encode(value)
        }
    }

    var description: String {
        switch self {
        case .number(let value):
            return String(format: "%.2f", value)
        case .notApplicable:
            return "NA"
        case .text(let value):
            return value
        }
    }
}
