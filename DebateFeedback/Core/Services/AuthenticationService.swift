//
//  AuthenticationService.swift
//  DebateFeedback
//
//

import Foundation
import SwiftData

protocol AuthenticationServicing {
    func loginAsTeacher(name: String) async throws -> Teacher
    func loginAsGuest()
    func logout()
}

@Observable
final class AuthenticationService {
    static let shared = AuthenticationService()

    private(set) var isAuthenticated = false
    private(set) var currentTeacher: Teacher?
    private let apiClient: APIClientProtocol
    private let keychainService: KeychainStoring

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        keychainService: KeychainStoring = KeychainService.shared
    ) {
        self.apiClient = apiClient
        self.keychainService = keychainService
        checkStoredAuth()
    }

    // MARK: - Authentication Methods

    func loginAsTeacher(name: String) async throws -> Teacher {
        // Track login initiated
        AnalyticsService.shared.logLoginInitiated()

        guard let deviceId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.deviceId) else {
            // Track login failed
            AnalyticsService.shared.logError(
                type: "auth_error",
                message: "No device ID",
                screen: "AuthView",
                action: "login"
            )
            throw NetworkError.unknown(NSError(domain: "No device ID", code: -1))
        }

        do {
            // In mock mode, create a fake teacher
            if Constants.API.useMockData {
                let teacher = Teacher(
                    name: name,
                    deviceId: deviceId,
                    authToken: "mock_token_\(UUID().uuidString)",
                    isAdmin: false
                )

                // Store auth token
                await apiClient.setAuthToken(teacher.authToken)
                if let token = teacher.authToken {
                    _ = keychainService.saveAuthToken(token)
                } else {
                    _ = keychainService.deleteAuthToken()
                }
                UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.authToken) // Legacy cleanup
                UserDefaults.standard.set(teacher.id.uuidString, forKey: Constants.UserDefaultsKeys.currentTeacherId)

                self.currentTeacher = teacher
                self.isAuthenticated = true

                // Track successful login
                AnalyticsService.shared.logLoginSuccess(
                    teacherName: name,
                    deviceId: deviceId,
                    isReturning: false // Mock mode always false
                )

                return teacher
            }

            // Real API call
            let response: LoginResponse = try await apiClient.request(
                endpoint: .login,
                body: LoginRequest(teacherId: name, deviceId: deviceId)
            )

            let teacher = Teacher(
                id: UUID(uuidString: response.teacher.id) ?? UUID(),
                name: response.teacher.name,
                deviceId: deviceId,
                authToken: response.token,
                isAdmin: response.teacher.isAdmin
            )

            // Store auth token
            await apiClient.setAuthToken(response.token)
            _ = keychainService.saveAuthToken(response.token)
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.authToken) // Legacy cleanup
            UserDefaults.standard.set(teacher.id.uuidString, forKey: Constants.UserDefaultsKeys.currentTeacherId)

            self.currentTeacher = teacher
            self.isAuthenticated = true

            // Track successful login (returning user since API found them)
            AnalyticsService.shared.logLoginSuccess(
                teacherName: name,
                deviceId: deviceId,
                isReturning: true
            )

            return teacher
        } catch {
            // Track login failed
            AnalyticsService.shared.logError(
                type: "auth_error",
                message: error.localizedDescription,
                screen: "AuthView",
                action: "login"
            )
            throw error
        }
    }

    func loginAsGuest() {
        guard let deviceId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.deviceId) else {
            return
        }

        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.isGuestMode)
        self.isAuthenticated = true
        self.currentTeacher = nil

        // Track guest mode selected
        AnalyticsService.shared.logGuestModeSelected(deviceId: deviceId)
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.authToken) // Legacy cleanup
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.currentTeacherId)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.isGuestMode)
        _ = keychainService.deleteAuthToken()

        Task {
            await apiClient.setAuthToken(nil)
        }

        self.currentTeacher = nil
        self.isAuthenticated = false

        // Track logout
        AnalyticsService.shared.logLogout()
    }

    // MARK: - Private Methods

    private func checkStoredAuth() {
        // Prefer secure token storage (Keychain)
        let keychainToken = keychainService.getAuthToken()
        // Backward-compatible migration from UserDefaults
        let legacyToken = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.authToken)
        let token = keychainToken ?? legacyToken

        if let token,
           let teacherIdString = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.currentTeacherId),
           let _ = UUID(uuidString: teacherIdString) {

            if keychainToken == nil {
                _ = keychainService.saveAuthToken(token)
            }
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.authToken)

            // In production, validate token with backend
            // For now, just restore the session
            Task {
                await apiClient.setAuthToken(token)
            }

            // Would need to fetch teacher details from DB here
            self.isAuthenticated = true
        } else if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isGuestMode) {
            self.isAuthenticated = true
            self.currentTeacher = nil
        }
    }

    // MARK: - Helper Properties

    var isGuestMode: Bool {
        isAuthenticated && currentTeacher == nil
    }

    var canAccessHistory: Bool {
        isAuthenticated && currentTeacher != nil
    }
}

extension AuthenticationService: AuthenticationServicing {}

// MARK: - Request Models

struct LoginRequest: Encodable {
    let teacherId: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case teacherId = "teacher_id"
        case deviceId = "device_id"
    }
}
