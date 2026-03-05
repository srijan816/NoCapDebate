//
//  FeedbackListView.swift
//  DebateFeedback
//
//

import SwiftUI
import SwiftData

struct FeedbackListView: View {
    let debateSession: DebateSession

    @Environment(AppCoordinator.self) private var coordinator
    @Query private var allRecordings: [SpeechRecording]

    private var recordings: [SpeechRecording] {
        allRecordings.filter { $0.debateSession?.id == debateSession.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Debate Info Header
                debateInfoHeader

                // Recordings Grid
                if recordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings Yet",
                        systemImage: "mic.slash",
                        description: Text("Recordings will appear here after the debate")
                    )
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(recordings, id: \.id) { recording in
                            NavigationLink(destination: FeedbackDetailView(recording: recording)) {
                                FeedbackCard(recording: recording)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Summary
                if !recordings.isEmpty {
                    summaryStats
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if coordinator.canNavigateBack {
                    Button {
                        HapticManager.shared.light()
                        coordinator.navigateBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityLabel("Back button")
                    .accessibilityHint("Return to the previous step")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.shared.success()
                    coordinator.returnToDebateSetup()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Done button")
                .accessibilityHint("Return to home screen")
            }
        }
        .subtleBoundaryEffects(showTopEdge: true, showBottomEdge: true, intensity: 0.06)
        .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
    }

    // MARK: - Debate Info Header

    private var debateInfoHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundColor(Constants.Colors.primaryAction)

            Text(debateSession.motion)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Label(debateSession.format.displayName, systemImage: "person.3")
                Label(debateSession.studentLevel.displayName, systemImage: "graduationcap")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        VStack(spacing: 16) {
            Text("Summary")
                .font(.headline)

            HStack(spacing: 32) {
                StatBox(
                    title: "Total Speeches",
                    value: "\(recordings.count)",
                    icon: "mic.fill"
                )

                StatBox(
                    title: "Ready",
                    value: "\(readyCount)",
                    icon: "checkmark.circle.fill",
                    color: Constants.Colors.success
                )

                StatBox(
                    title: "Processing",
                    value: "\(processingCount)",
                    icon: "hourglass",
                    color: Constants.Colors.processing
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var readyCount: Int {
        recordings.filter { $0.feedbackStatus == .complete }.count
    }

    private var processingCount: Int {
        recordings.filter {
            $0.feedbackStatus == .processing ||
            ($0.feedbackStatus == .pending && $0.transcriptionStatus == .processing)
        }.count
    }
}

// MARK: - Feedback Card

struct FeedbackCard: View {
    let recording: SpeechRecording

    @State private var showingShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Spacer()

                Text("\(recording.durationSeconds / 60):\(String(format: "%02d", recording.durationSeconds % 60))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Speaker Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.speakerName)
                    .font(.headline)
                    .lineLimit(1)

                Text(recording.speakerPosition)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Status
            statusView

            // View indicator for completed feedback
            if recording.feedbackStatus == .complete {
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingShareSheet) {
            if let url = recording.feedbackUrl {
                ShareSheet(items: [URL(string: url)!])
            }
        }
    }

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if recording.feedbackStatus == .processing || recording.transcriptionStatus == .processing {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }

            if let detail = recording.failureDetails {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(Constants.Colors.failed)
            }
        }
        .padding(.vertical, 4)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                if let urlString = recording.feedbackUrl,
                   let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("View", systemImage: "doc.text")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Constants.Colors.primaryAction)

            Button {
                showingShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .padding(8)
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusColor: Color {
        if recording.failureDetails != nil {
            return Constants.Colors.failed
        }

        switch recording.feedbackStatus {
        case .complete:
            return Constants.Colors.complete
        case .processing:
            return Constants.Colors.processing
        case .failed:
            return Constants.Colors.failed
        case .pending:
            if recording.transcriptionStatus == .processing {
                return Constants.Colors.primaryBlue
            }
            return recording.uploadStatus == .uploading ? Constants.Colors.uploading : Constants.Colors.pending
        }
    }

    private var statusText: String {
        if let detail = recording.failureDetails {
            return detail
        }

        if recording.feedbackStatus == .complete {
            return "✓ Ready"
        }

        if recording.feedbackStatus == .processing {
            return "Generating feedback"
        }

        if recording.transcriptionStatus == .processing {
            return "Transcribing"
        }

        if recording.uploadStatus == .uploading {
            return "Uploading..."
        }

        if recording.uploadStatus == .failed {
            return "Upload Failed"
        }

        return "Pending"
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

    return NavigationStack {
        FeedbackListView(debateSession: session)
            .environment(AppCoordinator())
            .modelContainer(container)
    }
}
