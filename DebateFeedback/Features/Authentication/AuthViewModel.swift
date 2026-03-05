//
//  AuthViewModel.swift
//  DebateFeedback
//
//

import Foundation
import SwiftData

@Observable
final class AuthViewModel {
    var teacherName = ""
    var isLoading = false
    var showError = false
    var errorMessage = ""
    var isAuthenticated = false
    var authenticatedTeacher: Teacher?

    private let authService: AuthenticationServicing

    init(authService: AuthenticationServicing = AuthenticationService.shared) {
        self.authService = authService
    }

    func loginAsTeacher() async {
        guard !teacherName.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let teacher = try await authService.loginAsTeacher(name: teacherName)
            authenticatedTeacher = teacher
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func loginAsGuest() {
        authService.loginAsGuest()
        authenticatedTeacher = nil
        isAuthenticated = true
    }
}
