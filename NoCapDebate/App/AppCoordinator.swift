//
//  AppCoordinator.swift
//  DebateFeedback
//
//

import SwiftUI

@Observable
final class AppCoordinator {
    enum Screen {
        case authentication
        case debateSetup
        case timer(debateSession: DebateSession)
        case feedback(debateSession: DebateSession)
        case history
    }

    var currentScreen: Screen = .debateSetup
    var navigationPath = [Screen]()

    // State management
    var isGuestMode: Bool = false
    var currentTeacher: Teacher?
    var currentDebateSession: DebateSession?
    private let authService: AuthenticationServicing

    init(authService: AuthenticationServicing = AuthenticationService.shared) {
        self.authService = authService
        // Check if user was previously logged in
        checkPreviousSession()
    }

    // MARK: - Navigation Methods

    func navigateTo(_ screen: Screen) {
        currentScreen = screen
        navigationPath.append(screen)
    }

    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
            if let lastScreen = navigationPath.last {
                currentScreen = lastScreen
            } else {
                currentScreen = .authentication
            }
        }
    }

    func resetToRoot() {
        navigationPath.removeAll()
        currentScreen = .debateSetup
        currentDebateSession = nil
    }

    func returnToDebateSetup() {
        navigationPath = [.debateSetup]
        currentScreen = .debateSetup
        currentDebateSession = nil
    }

    // MARK: - Authentication Flow

    func loginAsTeacher(_ teacher: Teacher) {
        self.currentTeacher = teacher
        self.isGuestMode = false
        UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKeys.isGuestMode)
        navigateTo(.debateSetup)
    }

    func loginAsGuest() {
        self.isGuestMode = true
        self.currentTeacher = nil
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.isGuestMode)
        navigateTo(.debateSetup)
    }

    func logout() {
        authService.logout()
        currentTeacher = nil
        isGuestMode = false
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.isGuestMode)
        resetToRoot()
    }

    // MARK: - Debate Flow

    func startDebate(session: DebateSession) {
        self.currentDebateSession = session
        navigateTo(.timer(debateSession: session))
    }

    func finishDebate() {
        guard let session = currentDebateSession else { return }
        navigateTo(.feedback(debateSession: session))
    }

    func viewHistory() {
        navigateTo(.history)
    }

    // MARK: - Session Persistence

    private func checkPreviousSession() {
        // B2C mode enters directly into daily drills. Legacy auth state is ignored.
        isGuestMode = true
        currentScreen = .debateSetup
        navigationPath = [.debateSetup]
    }

    // MARK: - Helper Methods

    var canAccessHistory: Bool {
        !isGuestMode && currentTeacher != nil
    }

    var canAccessAutoPopulation: Bool {
        !isGuestMode && currentTeacher != nil
    }

    var canNavigateBack: Bool {
        navigationPath.count > 1
    }
}
