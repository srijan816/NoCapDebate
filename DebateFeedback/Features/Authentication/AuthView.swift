//
//  AuthView.swift
//  DebateFeedback
//
//

import SwiftUI

struct AuthView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            // Light background with subtle glitters
            Constants.Colors.backgroundLight
                .ignoresSafeArea()

            SubtleGlitterView()
                .ignoresSafeArea()

            VStack(spacing: 50) {
                Spacer()

                // App Logo/Title with Mascot
                VStack(spacing: 24) {
                    // Mascot image - the image already has its own background
                    Image("mascot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 225, height: 225)

                    Text("DebateMate")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text("Intelligent feedback for modern debate")
                        .font(.body)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Login Section
                VStack(spacing: 20) {
                    // Teacher Login
                    VStack(spacing: 16) {
                        TextField("Teacher Name", text: $viewModel.teacherName)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .disabled(viewModel.isLoading)
                            .padding()
                            .background(Constants.Colors.backgroundSecondary)
                            .foregroundColor(Constants.Colors.textPrimary)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Constants.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                            )

                        Button {
                            HapticManager.shared.light()
                            Task {
                                await viewModel.loginAsTeacher()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Login as Teacher")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: Constants.Sizing.minimumTapTarget)
                        }
                        .gradientButtonStyle(isEnabled: !viewModel.teacherName.isEmpty && !viewModel.isLoading)
                        .disabled(viewModel.teacherName.isEmpty || viewModel.isLoading)
                        .accessibilityLabel("Login as teacher button")
                        .accessibilityHint("Sign in with your teacher account to access full features")
                    }

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Constants.Colors.textTertiary.opacity(0.3))
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Constants.Colors.textTertiary.opacity(0.3))
                    }

                    // Guest Login
                    Button {
                        HapticManager.shared.light()
                        viewModel.loginAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: Constants.Sizing.minimumTapTarget)
                            .background(Constants.Colors.backgroundLight)
                            .foregroundColor(Constants.Colors.textPrimary)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Constants.Colors.softPink.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Continue as guest button")
                    .accessibilityHint("Use the app with limited features and no history")

                    // Guest Mode Info
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text("Limited features, no history")
                            .font(.caption)
                    }
                    .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Footer
                Text("Capstone Debate ©")
                    .font(.caption2)
                    .foregroundColor(Constants.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.isAuthenticated) { _, authenticated in
            if authenticated {
                HapticManager.shared.success()
                if let teacher = viewModel.authenticatedTeacher {
                    coordinator.loginAsTeacher(teacher)
                } else {
                    coordinator.loginAsGuest()
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(AppCoordinator())
}
