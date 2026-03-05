//
//  Endpoints.swift
//  DebateFeedback
//
//

import Foundation

enum Endpoint {
    case identifyCoach
    case getCoachHomeState(studentId: Int)
    case getNextDrill(studentId: Int)
    case uploadDrillAttempt
    case getLeagueCurrent(studentId: Int)
    case login
    case getCurrentSchedule(teacherId: String, timestamp: String, classId: String? = nil)
    case createDebate
    case initiateUpload
    case completeUpload
    case uploadSpeech
    case getSpeechStatus(speechId: String)
    case getFeedbackContent(speechId: String)
    case getDebateHistory(teacherId: String, limit: Int)

    var path: String {
        switch self {
        case .identifyCoach:
            return "/coach/identify"
        case .getCoachHomeState(let studentId):
            return "/coach/home/\(studentId)"
        case .getNextDrill(let studentId):
            return "/drills/next/\(studentId)"
        case .uploadDrillAttempt:
            return "/drills/attempt"
        case .getLeagueCurrent(let studentId):
            return "/leagues/current/\(studentId)"
        case .login:
            return "/auth/login"
        case .getCurrentSchedule(let teacherId, let timestamp, let classId):
            var path = "/schedule/current?teacher_id=\(teacherId)&timestamp=\(timestamp)"
            if let classId {
                path += "&class_id=\(classId)"
            }
            return path
        case .createDebate:
            return "/debates/create"
        case .initiateUpload:
            return "/uploads/initiate"
        case .completeUpload:
            return "/uploads/complete"
        case .uploadSpeech:
            return "/speeches"
        case .getSpeechStatus(let speechId):
            return "/speeches/\(speechId)"
        case .getFeedbackContent(let speechId):
            return "/speeches/\(speechId)/feedback"
        case .getDebateHistory(let teacherId, let limit):
            return "/teachers/\(teacherId)/debates?limit=\(limit)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .identifyCoach, .login, .createDebate, .initiateUpload, .completeUpload, .uploadSpeech, .uploadDrillAttempt:
            return .post
        case .getCoachHomeState, .getNextDrill, .getLeagueCurrent, .getCurrentSchedule, .getSpeechStatus, .getFeedbackContent, .getDebateHistory:
            return .get
        }
    }

    func url(baseURL: String = Constants.API.baseURL) -> URL? {
        URL(string: baseURL + path)
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
