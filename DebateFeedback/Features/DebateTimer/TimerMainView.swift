//
//  TimerMainView.swift
//  DebateFeedback
//
//

import SwiftUI
import SwiftData
import UIKit

struct TimerMainView: View {
    let debateSession: DebateSession

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: TimerViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                timerContent(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TimerViewModel(debateSession: debateSession, modelContext: modelContext)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showError ?? false },
            set: { if !$0 { viewModel?.showError = false } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func timerContent(viewModel: TimerViewModel) -> some View {
        ZStack {
            // Light background with subtle glitters
            Constants.Colors.backgroundLight
                .ignoresSafeArea()

            SubtleGlitterView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Motion Header
                motionHeader(viewModel: viewModel)

                // Main Timer Display
                Spacer()

                timerDisplay(viewModel: viewModel)

                Spacer()

                // Control Buttons
                controlButtons(viewModel: viewModel)

                // Navigation
                speakerNavigation(viewModel: viewModel)

                // Recordings List (if any completed)
                if !viewModel.recordings.isEmpty {
                    recordingsList(viewModel: viewModel)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isRecording)
        .toolbarBackground(Constants.Colors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if coordinator.canNavigateBack {
                    Button {
                        HapticManager.shared.light()
                        coordinator.navigateBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 0.4 : 1.0)
                    .accessibilityLabel("Back button")
                    .accessibilityHint("Return to the previous step")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("View Feedback") {
                    HapticManager.shared.success()
                    coordinator.finishDebate()
                }
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.softMint)
                .accessibilityLabel("View feedback button")
                .accessibilityHint("Navigate to feedback list for all speeches")
            }
        }
        .subtleBoundaryEffects(showTopEdge: false, showBottomEdge: true, intensity: 0.07)
        .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
        .onAppear {
            updateIdleTimer(for: viewModel)
        }
        .onChange(of: viewModel.timerState) { _ in
            updateIdleTimer(for: viewModel)
        }
        .onChange(of: viewModel.isRecording) { _ in
            updateIdleTimer(for: viewModel)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Motion Header

    private func motionHeader(viewModel: TimerViewModel) -> some View {
        VStack(spacing: 12) {
            // Motion text
            Text(debateSession.motion)
                .font(.body)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(Constants.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Current Speaker Card
            HStack(spacing: 16) {
                // Avatar circle
                Circle()
                    .fill(Constants.Colors.primaryBlue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(viewModel.currentSpeaker.name.prefix(1)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentSpeaker.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(viewModel.currentSpeaker.position)
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: Constants.Colors.textTertiary.opacity(0.2), cornerRadius: 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Constants.Colors.backgroundSecondary)
    }

    private func updateIdleTimer(for viewModel: TimerViewModel) {
        let shouldDisable = viewModel.timerState == .running || viewModel.isRecording
        UIApplication.shared.isIdleTimerDisabled = shouldDisable
    }

    // MARK: - Timer Display

    private func timerDisplay(viewModel: TimerViewModel) -> some View {
        VStack(spacing: 24) {
            // Timer display with warnings
            VStack(spacing: 16) {
                // Warning indicator
                if viewModel.isRecording && !viewModel.isOvertime {
                    warningIndicator(for: viewModel)
                        .transition(.opacity.combined(with: .scale))
                }

                // Timer
                HStack(spacing: 16) {
                    Spacer()

TimerTextView(viewModel: viewModel)

                    // Bell Icon
                    if viewModel.isRecording {
                        Button {
                            HapticManager.shared.light()
                            viewModel.ringBell()
                        } label: {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Constants.Colors.primaryBlue)
                                .symbolEffect(.bounce, value: viewModel.elapsedTime)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ring bell")
                        .accessibilityHint("Manually ring the bell")
                    }

                    Spacer()
                }

                // Simple progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Constants.Colors.textTertiary.opacity(0.2))
                            .frame(height: 10)

                        Capsule()
                            .fill(viewModel.isOvertime ? Color.red : Constants.Colors.primaryBlue)
                            .frame(width: geometry.size.width * viewModel.progressPercentage, height: 10)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 40)

            }
            .padding(24)
            .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: nil, cornerRadius: 20)

            // Recording indicator
            if viewModel.isRecording {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Constants.Colors.recordingActive)
                        .frame(width: 12, height: 12)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)

                    Text("Recording")
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textPrimary)
                }
            }
        }
    }

    // MARK: - Warning Indicator

    @ViewBuilder
    private func warningIndicator(for viewModel: TimerViewModel) -> some View {
        let level = viewModel.currentWarningLevel

        switch level {
        case .oneMinute:
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.orange)
                    .symbolEffect(.pulse, options: .repeating)
                Text("1 minute remaining")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(20)
            .accessibilityLabel("Warning: 1 minute remaining")

        case .thirtySeconds:
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)
                Text("30 seconds remaining")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .cornerRadius(20)
            .accessibilityLabel("Warning: 30 seconds remaining")

        case .fifteenSeconds:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)
                Text("15 seconds remaining!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.15))
            .cornerRadius(20)
            .accessibilityLabel("Critical warning: 15 seconds remaining")

        case .none:
            EmptyView()
        }
    }

    // MARK: - Control Buttons

    private func controlButtons(viewModel: TimerViewModel) -> some View {
        HStack(spacing: 20) {
            if viewModel.isRecording {
                Button {
                    HapticManager.shared.heavy()
                    viewModel.stopTimer()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text("Stop Recording")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.Sizing.minimumTapTarget * 1.5)
                }
                .gradientButtonStyle(
                    gradient: LinearGradient(
                        colors: [Color.red.opacity(0.9), Color.red.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .accessibilityLabel("Stop recording button")
                .accessibilityHint("Stops recording the current speech")
            } else {
                Button {
                    HapticManager.shared.heavy()
                    viewModel.startTimer()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                        Text("Start Recording")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.Sizing.minimumTapTarget * 1.5)
                }
                .gradientButtonStyle()
                .accessibilityLabel("Start recording button")
                .accessibilityHint("Starts recording the current speech and begins the timer")
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }

    // MARK: - Speaker Navigation

    private func speakerNavigation(viewModel: TimerViewModel) -> some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.light()
                viewModel.previousSpeaker()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                        .fontWeight(.medium)
                }
                .foregroundColor(viewModel.canGoBack && !viewModel.isRecording ? Constants.Colors.textPrimary : Constants.Colors.textTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Constants.Colors.backgroundSecondary)
                .cornerRadius(25)
            }
            .disabled(!viewModel.canGoBack || viewModel.isRecording)
            .opacity(viewModel.canGoBack && !viewModel.isRecording ? 1.0 : 0.4)
            .accessibilityLabel("Previous speaker button")
            .accessibilityHint(viewModel.canGoBack ? "Go to previous speaker" : "No previous speaker available")

            Spacer()

            Text(viewModel.speakerProgress)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Constants.Colors.textSecondary)

            Spacer()

            Button {
                HapticManager.shared.light()
                viewModel.nextSpeaker()
            } label: {
                HStack(spacing: 8) {
                    Text("Next")
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(viewModel.canGoForward && !viewModel.isRecording ? Constants.Colors.textPrimary : Constants.Colors.textTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Constants.Colors.backgroundSecondary)
                .cornerRadius(25)
            }
            .disabled(!viewModel.canGoForward || viewModel.isRecording)
            .opacity(viewModel.canGoForward && !viewModel.isRecording ? 1.0 : 0.4)
            .accessibilityLabel("Next speaker button")
            .accessibilityHint(viewModel.canGoForward ? "Go to next speaker" : "No next speaker available")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Constants.Colors.backgroundSecondary)
    }

    // MARK: - Recordings List

    private func recordingsList(viewModel: TimerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed Speeches")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.textPrimary)
                    Text("\(viewModel.completedSpeeches) recordings")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.caption2)
                    Text("Double-tap to play")
                        .font(.caption2)
                }
                .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recordings, id: \.id) { recording in
                        RecordingCard(recording: recording, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Constants.Colors.backgroundSecondary)
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: SpeechRecording
    @Bindable var viewModel: TimerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.speakerName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(1)

                    Text(recording.speakerPosition)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Playback indicator
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.body)
                        .foregroundColor(Constants.Colors.primaryBlue)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                }
            }

            // Duration
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(Constants.Colors.textSecondary)
                Text(viewModel.getPlaybackTime(for: recording))
                    .font(.caption2)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            // Status
            HStack {
                statusIndicator

                if recording.uploadStatus == .uploading,
                   let progress = viewModel.uploadProgress[recording.id] {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Constants.Colors.primaryBlue)
                } else if let detail = recording.failureDetails {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.failed)
                        .lineLimit(2)
                }
            }

            // Playback progress
            if isPlaying {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Constants.Colors.textTertiary.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(Constants.Colors.primaryBlue)
                            .frame(width: geometry.size.width * viewModel.getPlaybackProgress(for: recording), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(16)
        .frame(width: 170)
        .frame(minHeight: 130)
        .softCard(
            backgroundColor: Constants.Colors.cardBackground,
            borderColor: isPlaying ? Constants.Colors.primaryBlue : nil,
            cornerRadius: 16
        )
        .scaleEffect(isPlaying ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPlaying)
        .onTapGesture(count: 2) {
            viewModel.togglePlayback(for: recording)
        }
    }

    private var isPlaying: Bool {
        viewModel.playingRecordingId == recording.id && viewModel.isPlaying
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
    }

    private var statusColor: Color {
        if recording.failureDetails != nil {
            return Constants.Colors.failed
        }

        switch recording.aggregatedProcessingStatus {
        case .complete:
            return Constants.Colors.complete
        case .processing:
            return recording.transcriptionStatus == .processing ? Constants.Colors.primaryBlue : Constants.Colors.processing
        case .failed:
            return Constants.Colors.failed
        case .pending:
            return recording.uploadStatus == .uploading ? Constants.Colors.uploading : Constants.Colors.pending
        }
    }

    private var statusText: String {
        if let detail = recording.failureDetails {
            return detail
        }

        if recording.feedbackStatus == .complete {
            return "Ready"
        }

        if recording.feedbackStatus == .processing {
            return "Generating feedback"
        }

        if recording.transcriptionStatus == .processing {
            return "Transcribing"
        }

        if recording.transcriptionStatus == .complete && recording.feedbackStatus == .pending {
            return "Queued for feedback"
        }

        if recording.uploadStatus == .uploading {
            return "Uploading"
        }

        return "Pending"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DebateSession.self, configurations: config)

    let session = DebateSession(
        motion: "This house believes that social media does more harm than good",
        format: .wsdc,
        studentLevel: .secondary,
        speechTimeSeconds: 300
    )

    var composition = TeamComposition()
    composition.prop = [UUID().uuidString, UUID().uuidString, UUID().uuidString]
    composition.opp = [UUID().uuidString, UUID().uuidString, UUID().uuidString]
    session.teamComposition = composition

    return NavigationStack {
        TimerMainView(debateSession: session)
            .environment(AppCoordinator())
            .modelContainer(container)
    }
}
