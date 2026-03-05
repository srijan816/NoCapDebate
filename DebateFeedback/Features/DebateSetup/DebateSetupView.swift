import SwiftUI

struct DebateSetupView: View {
    @State private var viewModel = SetupViewModel()

    var body: some View {
        ZStack {
            Constants.Colors.backgroundLight
                .ignoresSafeArea()

            SubtleGlitterView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    drillCard
                    primaryAction

                    if viewModel.isRecording {
                        recordingCard
                    }

                    if viewModel.showResult {
                        resultCard
                    }

                    leagueCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("DebateMate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Constants.Colors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.initializeIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            statChip(icon: "flame.fill", title: "Streak", value: "\(viewModel.streak)")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("XP")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                    Spacer()
                    Text("\(viewModel.dailyXp) / \(viewModel.dailyGoal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.textPrimary)
                }

                GeometryReader { geo in
                    Capsule()
                        .fill(Constants.Colors.textTertiary.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Constants.Colors.primaryBlue)
                                .frame(width: geo.size.width * min(1.0, Double(viewModel.dailyXp) / Double(max(1, viewModel.dailyGoal))))
                        }
                }
                .frame(height: 10)
            }
            .padding(12)
            .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: Constants.Colors.textTertiary.opacity(0.2), cornerRadius: 14)

            statChip(icon: "diamond.fill", title: "Gems", value: "\(viewModel.gems)")
        }
    }

    private var drillCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next Micro-Drill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textSecondary)

            Text(viewModel.nextDrillType.replacingOccurrences(of: "_", with: " "))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text(viewModel.nextDrillPrompt)
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)

            HStack {
                Label("\(viewModel.maxDurationSeconds)s", systemImage: "timer")
                Spacer()
                Text("Level \(viewModel.level)")
            }
            .font(.caption)
            .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(18)
        .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: Constants.Colors.softCyan.opacity(0.4), cornerRadius: 16)
    }

    private var primaryAction: some View {
        Button {
            viewModel.handlePrimaryAction()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                Text(viewModel.ctaTitle)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .gradientButtonStyle(isEnabled: !viewModel.isSubmitting)
        .disabled(viewModel.isSubmitting)
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recording", systemImage: "waveform")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.recordingActive)
                Spacer()
                Text("\(viewModel.recordingSeconds)s / \(viewModel.maxDurationSeconds)s")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            GeometryReader { geo in
                Capsule()
                    .fill(Constants.Colors.textTertiary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Constants.Colors.recordingActive)
                            .frame(width: geo.size.width * viewModel.recordingProgress)
                    }
            }
            .frame(height: 10)
        }
        .padding(16)
        .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: Constants.Colors.recordingActive.opacity(0.3), cornerRadius: 14)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Result")
                    .font(.headline)
                    .foregroundColor(Constants.Colors.textPrimary)
                Spacer()
                Text("Score \(viewModel.lastScore ?? 0)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primaryBlue)
            }

            if let xp = viewModel.lastXpAwarded {
                Text("+\(xp) XP")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.softMint)
            }

            Text(viewModel.lastPraise)
                .font(.body)
                .foregroundColor(Constants.Colors.textPrimary)

            Text(viewModel.lastCritique)
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(16)
        .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: Constants.Colors.softMint.opacity(0.35), cornerRadius: 16)
    }

    private var leagueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("League")
                .font(.headline)
                .foregroundColor(Constants.Colors.textPrimary)

            HStack {
                Text(viewModel.leagueTier)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.softPink)

                Spacer()

                Text("Rank #\(viewModel.leagueRank) / \(viewModel.leagueTotalMembers)")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
        }
        .padding(16)
        .softCard(backgroundColor: Constants.Colors.cardBackground, borderColor: Constants.Colors.softPink.opacity(0.3), cornerRadius: 16)
    }

    private func statChip(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Constants.Colors.softPink)
            Text(title)
                .font(.caption2)
                .foregroundColor(Constants.Colors.textSecondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.textPrimary)
        }
        .frame(width: 76)
        .padding(.vertical, 10)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Constants.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }
}
