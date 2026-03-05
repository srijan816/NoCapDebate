//
//  FeedbackDetailView.swift
//  DebateFeedback
//
//

import SwiftUI
import WebKit

struct FeedbackDetailView: View {
    let recording: SpeechRecording
    private let apiClient: APIClientProtocol

    @State private var feedbackContent: String = ""
    @State private var sections: [FeedbackSectionData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingShareSheet = false
    @State private var webViewLoading = false
    @State private var webViewError: String?
    @State private var playbackService = AudioPlaybackService()
    @State private var activeMomentID: UUID?
    @State private var playbackErrorMessage: String?
    @State private var displayMode: FeedbackDisplayMode
    @State private var remoteAudioUrl: URL?

    init(recording: SpeechRecording, apiClient: APIClientProtocol = APIClient.shared) {
        self.recording = recording
        self.apiClient = apiClient
        let initialMode: FeedbackDisplayMode = .highlights
        _displayMode = State(initialValue: initialMode)
    }

    var body: some View {
        let displayModes = availableDisplayModes
        let showTabs = displayModes.count > 1

        return VStack(spacing: 0) {
            if showTabs {
                HStack(spacing: 0) {
                    ForEach(displayModes) { mode in
                        FeedbackModeTab(
                            title: mode.rawValue,
                            isSelected: displayMode == mode,
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    displayMode = mode
                                }
                                AnalyticsService.shared.logFeedbackTabSwitched(to: mode.rawValue)
                            }
                        )
                    }
                }
                .padding(.top)
                .background(Color(uiColor: .systemBackground))
            }

            Group {
                switch displayMode {
                case .document:
                    documentFeedbackView
                case .highlights:
                    highlightsFeedbackView
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let urlString = recording.feedbackUrl, URL(string: urlString) != nil {
                        Button {
                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                                // Track opening feedback in Safari
                                AnalyticsService.shared.logFeedbackSharedSafari(speakerPosition: recording.speakerPosition)
                            }
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }

                        Button {
                            showingShareSheet = true
                            // Track share sheet opened
                            AnalyticsService.shared.logFeedbackSharedSystem(speakerPosition: recording.speakerPosition)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = recording.feedbackUrl {
                ShareSheet(items: [URL(string: url)!])
            }
        }
        .task {
            await loadFeedback()
        }
        .onAppear {
            // Track feedback detail viewed
            let playableMoments = sections.flatMap { $0.playableMoments }
            AnalyticsService.shared.logFeedbackDetailViewed(
                speakerPosition: recording.speakerPosition,
                hasPlayableMoments: !playableMoments.isEmpty,
                playableMomentsCount: playableMoments.count
            )
        }
        .onChange(of: playbackService.isPlaying) {
            if !playbackService.isPlaying {
                activeMomentID = nil
            }
        }
        .onDisappear {
            playbackService.stop()
        }
        .alert("Playback Error", isPresented: Binding(
            get: { playbackErrorMessage != nil },
            set: { if !$0 { playbackErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(playbackErrorMessage ?? "")
        }
    }

    private var availableDisplayModes: [FeedbackDisplayMode] {
        if recording.feedbackUrl == nil {
            return [.highlights]
        }
        return [.highlights, .document]
    }

    private var documentFeedbackView: some View {
        Group {
            if let urlString = recording.feedbackUrl, let url = URL(string: urlString) {
                VStack(spacing: 0) {
                    speakerInfoBar

                    if let error = webViewError {
                        documentErrorView(url: url, error: error)
                    } else {
                        WebView(url: url, isLoading: $webViewLoading, error: $webViewError)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Document Unavailable",
                    systemImage: "doc.text.fill",
                    description: Text("Switch to Highlights to see structured feedback")
                )
            }
        }
    }

    private var speakerInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.speakerName)
                    .font(.headline)
                Text(recording.speakerPosition)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if webViewLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
            Text("\(recording.durationSeconds / 60):\(String(format: "%02d", recording.durationSeconds % 60))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func documentErrorView(url: URL, error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to Load Feedback")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Button {
                UIApplication.shared.open(url)
                // Track opening feedback in Safari
                AnalyticsService.shared.logFeedbackSharedSafari(speakerPosition: recording.speakerPosition)
            } label: {
                Label("Open in Safari", systemImage: "safari")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var highlightsFeedbackView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                speakerHeader

                transcriptSection

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    feedbackContentView
                }
            }
            .padding()
        }
    }

    // MARK: - Speaker Header

    private var speakerHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.speakerName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(recording.speakerPosition)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    if playbackService.isPlaying {
                        playbackService.pause()
                    } else {
                        // Resumes if paused/stopped but has file state; otherwise starts fresh
                        if playbackService.currentFileURL != nil {
                            playbackService.resume()
                        } else {
                            let fileURL = URL(fileURLWithPath: recording.localFilePath)
                            try? playbackService.play(from: fileURL)
                            activeMomentID = nil
                        }
                    }
                } label: {
                    Image(systemName: playbackService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Constants.Colors.primaryAction)
                }
                .padding(.trailing, 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(recording.durationSeconds / 60):\(String(format: "%02d", recording.durationSeconds % 60))")
                        .font(.headline)
                        .foregroundColor(Constants.Colors.primaryAction)
                }
            }

            Divider()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading feedback...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to Load Feedback")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let urlString = recording.feedbackUrl {
                Button {
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                        // Track opening feedback in Safari
                        AnalyticsService.shared.logFeedbackSharedSafari(speakerPosition: recording.speakerPosition)
                    }
                } label: {
                    Label("Open Feedback", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Feedback Content View

    private var feedbackContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(displaySections) { section in
                FeedbackSectionView(
                    section: section,
                    playMoment: playMoment,
                    isMomentActive: { moment in
                        activeMomentID == moment.id && playbackService.isPlaying
                    }
                )
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primaryAction)

                Spacer()

                if let statusText = transcriptStatusLabel {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let transcript = transcriptText {
                Text(transcript)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let transcriptURL = transcriptURL {
                Button {
                    UIApplication.shared.open(transcriptURL)
                    // Track transcript viewed
                    AnalyticsService.shared.logTranscriptViewed(speakerPosition: recording.speakerPosition)
                } label: {
                    Label("Open Transcript", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.primaryBlue)

                Text("Transcript opens in your browser.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Transcript will appear once the transcription finishes.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private var displaySections: [FeedbackSectionData] {
        if !sections.isEmpty {
            return sections
        }

        if feedbackContent.isEmpty {
            return [FeedbackSectionData(
                title: "Feedback",
                content: "Feedback will appear here once processing is complete.",
                playableMoments: []
            )]
        }

        return parseFeedbackSections(from: feedbackContent)
    }

    private var transcriptText: String? {
        let trimmed = recording.transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var transcriptURL: URL? {
        guard let urlString = recording.transcriptUrl,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    private var transcriptStatusLabel: String? {
        switch recording.transcriptionStatus {
        case .complete:
            return "Ready"
        case .processing:
            return "Transcribing..."
        case .failed:
            return "Failed"
        case .pending:
            return nil
        }
    }

    // MARK: - Load Feedback

    private func loadFeedback() async {
        if isLoading == false && !sections.isEmpty {
            return
        }

        if let cached = recording.feedbackContent, !cached.isEmpty {
            feedbackContent = cached
            sections = parseFeedbackSections(from: cached)
            isLoading = false
            return
        }

        guard let speechId = recording.speechId else {
            errorMessage = "Feedback is processing. Please check back soon."
            isLoading = false
            return
        }

        do {
            let response: FeedbackContentResponse = try await apiClient.request(
                endpoint: .getFeedbackContent(speechId: speechId)
            )

            // DIAGNOSTIC LOGGING - Phase 1
            print("========== FEEDBACK RESPONSE DIAGNOSTICS ==========")
            print("📥 speechId: \(response.speechId)")
            print("📥 feedbackText length: \(response.resolvedFeedbackText.count) chars")
            print("📥 playableMoments: \(response.playableMoments?.count ?? 0) items")
            if let moments = response.playableMoments {
                for (index, moment) in moments.enumerated() {
                    print("   [\(index)] \(moment.timestampLabel) @ \(moment.timestampSeconds)s - \(moment.endTimestampSeconds ?? -1)s: \(moment.summary.prefix(50))...")
                }
            }
            print("📥 audioUrl: \(response.audioUrl ?? "⚠️ NIL - BACKEND NOT SENDING audio_url")")
            print("📥 scores: \(response.scores?.description ?? "nil")")
            print("===================================================")

            let resolvedText = response.resolvedFeedbackText
            if resolvedText.isEmpty, let responseSections = response.sections, !responseSections.isEmpty {
                feedbackContent = responseSections
                    .map { "\($0.title)\n\($0.content)" }
                    .joined(separator: "\n\n")
            } else {
                feedbackContent = resolvedText
            }
            sections = buildSections(from: response)

            recording.feedbackContent = feedbackContent
            if let moments = response.playableMoments {
                recording.playableMoments = moments
            }
            
            if let urlString = response.audioUrl, let url = URL(string: urlString) {
                print("✅ Remote audio URL set: \(url)")
                self.remoteAudioUrl = url
            } else {
                print("⚠️ No remote audio URL - playback will fail if local file is missing")
            }
            
            await MainActor.run {
                // Persisting handles by SwiftData autosave on main context usually
            }

            isLoading = false
        } catch {
            print("❌ loadFeedback FAILED: \(error.localizedDescription)")
            errorMessage = "Feedback is ready in the web viewer. Tap the menu to open it."
            isLoading = false
        }
    }

    // MARK: - Parse Feedback

    private func buildSections(from response: FeedbackContentResponse) -> [FeedbackSectionData] {
        var resultSections: [FeedbackSectionData] = []
        
        // Parse sections from feedback text
        if let responseSections = response.sections, !responseSections.isEmpty {
            resultSections = responseSections.map { section in
                FeedbackSectionData(
                    title: section.title,
                    content: section.content,
                    playableMoments: []
                )
            }
        } else {
            resultSections = parseFeedbackSections(from: response.resolvedFeedbackText)
        }
        
        // 3. Inject Structured Playable Moments
        if let moments = response.playableMoments, !moments.isEmpty {
            if let index = resultSections.firstIndex(where: { $0.title.lowercased().contains("playable") }) {
                let existing = resultSections[index]
                resultSections[index] = FeedbackSectionData(title: existing.title, content: existing.content, playableMoments: moments)
            } else {
                // Always add Playable Moments as the first section if not present
                let specialSection = FeedbackSectionData(title: "Playable Moments", content: "", playableMoments: moments)
                resultSections.insert(specialSection, at: 0)
            }
        } else if resultSections.isEmpty && !response.resolvedFeedbackText.isEmpty {
             // If we have text but no sections and no API moments, try to see if we have cached moments?
             // Or just rely on what we parsed.
        }
        
        return resultSections
    }

    private func parseFeedbackSections(from content: String) -> [FeedbackSectionData] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [FeedbackSectionData] = []
        var currentTitle = "AI Feedback"
        var currentLines: [String] = []

        func flushSection() {
            let body = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else {
                currentLines.removeAll()
                return
            }

            let moments: [PlayableMoment] = [] // Structured moments are injected in buildSections
            sections.append(FeedbackSectionData(title: currentTitle, content: body, playableMoments: moments))
            currentLines.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                currentLines.append("")
                continue
            }

            if isLikelySectionHeader(line) {
                flushSection()
                currentTitle = line.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                continue
            }

            currentLines.append(line)
        }

        flushSection()

        if sections.isEmpty {
            sections.append(FeedbackSectionData(
                title: "AI Feedback",
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                playableMoments: [] // Structured moments come from API
            ))
        }

        return sections
    }

    private func isLikelySectionHeader(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        if line.hasSuffix(":") { return true }
        if line.count < 40, line == line.uppercased() { return true }

        let knownHeaders = ["overall", "summary", "strengths", "opportunities", "recommendations", "action items", "playable moments"]
        return knownHeaders.contains { line.lowercased().starts(with: $0) }
    }



    private func playMoment(_ moment: PlayableMoment) {
        // Track playable moment clicked (KEY METRIC!)
        let allMoments = sections.flatMap { $0.playableMoments }
        if let momentIndex = allMoments.firstIndex(where: { $0.id == moment.id }) {
            AnalyticsService.shared.logPlayableMomentClicked(
                speakerPosition: recording.speakerPosition,
                timestamp: moment.timestampLabel,
                index: momentIndex,
                totalMoments: allMoments.count
            )
        }

        // DIAGNOSTIC LOGGING - Phase 1
        print("========== PLAY MOMENT DIAGNOSTICS ==========")
        print("🎯 Requested moment: \(moment.timestampLabel) @ \(moment.timestampSeconds)s")
        print("📁 recording.localFilePath: \(recording.localFilePath)")
        
        // 1. Try to resolve the local file dynamically
        let localURL = FileManager.default.resolveCurrentPath(for: recording.localFilePath)
        print("📂 Resolved localURL: \(localURL?.path ?? "❌ NIL - file not found")")
        print("🌐 remoteAudioUrl: \(remoteAudioUrl?.absoluteString ?? "❌ NIL - backend didn't send audio_url")")
        
        // 2. Determine which URL to use (Local > Remote)
        guard let playURL = localURL ?? remoteAudioUrl else {
            let diagnosticError = """
            ❌ PLAYBACK FAILED - NO AUDIO SOURCE
            • Local file not found at: \(recording.localFilePath)
            • Remote URL: \(remoteAudioUrl?.absoluteString ?? "NOT PROVIDED BY BACKEND")
            
            FIX: Backend must return 'audio_url' in /speeches/{id}/feedback response
            """
            print(diagnosticError)
            playbackErrorMessage = "Audio unavailable. Local file missing, backend didn't provide URL."
            return
        }
        
        print("✅ Using playURL: \(playURL.path)")
        print("==============================================")

        do {
            if activeMomentID == moment.id {
                print("ℹ️ Toggling playback for active moment")
                if playbackService.isPlaying {
                    playbackService.pause()
                } else {
                    playbackService.resume()
                }
                return
            }

            // Check if we are already playing this specific URL
            if playbackService.currentFileURL == playURL {
                 print("ℹ️ Same file - seeking to \(moment.timestampSeconds)s")
                 playbackService.seek(to: moment.timestampSeconds)
                 if !playbackService.isPlaying {
                     playbackService.resume()
                 }
            } else {
                print("▶️ Starting new playback from \(playURL.lastPathComponent)")
                try playbackService.play(
                    from: playURL,
                    startingAt: moment.timestampSeconds,
                    endingAt: moment.endTimestampSeconds
                )
            }
            activeMomentID = moment.id
        } catch {
            print("❌ Playback error: \(error.localizedDescription)")
            playbackErrorMessage = "Playback failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Feedback Section

struct FeedbackSectionView: View {
    let section: FeedbackSectionData
    let playMoment: (PlayableMoment) -> Void
    let isMomentActive: (PlayableMoment) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.primaryAction)

            if section.playableMoments.isEmpty {
                Text(section.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 12) {
                    Text("Tap a moment to jump to that part of the recording.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(section.playableMoments) { moment in
                        PlayableMomentRow(
                            moment: moment,
                            isActive: isMomentActive(moment),
                            playMoment: playMoment
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PlayableMomentRow: View {
    let moment: PlayableMoment
    let isActive: Bool
    let playMoment: (PlayableMoment) -> Void
    @State private var showRecommendation = false

    private var accentColor: Color {
        moment.isPraise ? Color.green : Constants.Colors.primaryAction
    }

    private var categoryIcon: String {
        if moment.isPraise { return "star.fill" }
        switch moment.category {
        case "incomplete_argument": return "exclamationmark.triangle"
        case "dropped_argument": return "xmark.circle"
        case "excellent", "proved", "strategic_win": return "star.fill"
        default: return "lightbulb"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                playMoment(moment)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: categoryIcon)
                        .font(.caption)
                        .foregroundColor(accentColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(moment.timestampLabel)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(accentColor)
                        Text(moment.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isActive ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(accentColor)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isActive ? accentColor.opacity(0.12) : Color(uiColor: .systemBackground))
                .cornerRadius(moment.recommendation != nil ? 12 : 12)
                .cornerRadius(12, corners: moment.recommendation != nil ? [.topLeft, .topRight] : .allCorners)
            }
            .buttonStyle(.plain)

            // Recommendation panel — shown when recommendation is available
            if let rec = moment.recommendation, !rec.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showRecommendation.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showRecommendation ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text(showRecommendation ? "Hide advice" : "Show advice")
                            .font(.caption2)
                        Spacer()
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.06))
                }
                .buttonStyle(.plain)

                if showRecommendation {
                    Text(rec)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accentColor.opacity(0.04))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Bottom rounded corners
                Color.clear.frame(height: 0)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Corner radius helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct FeedbackSectionData: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let playableMoments: [PlayableMoment]
}

struct FeedbackModeTab: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? Constants.Colors.primaryAction : .secondary)

            Rectangle()
                .fill(isSelected ? Constants.Colors.primaryAction : Color.clear)
                .frame(height: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}



enum FeedbackDisplayMode: String, Identifiable, CaseIterable {
    case highlights = "Highlights"
    case document = "Document"

    var id: String { rawValue }
}

// MARK: - WebView Component

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var error: String?

    init(url: URL, isLoading: Binding<Bool> = .constant(false), error: Binding<String?> = .constant(nil)) {
        self.url = url
        self._isLoading = isLoading
        self._error = error
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.isLoading = $isLoading
        context.coordinator.error = $error

        // Only load if not already loaded
        if webView.url != url {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 30

            print("📱 Loading feedback URL: \(url.absoluteString)")
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, error: $error)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var isLoading: Binding<Bool>
        var error: Binding<String?>

        init(isLoading: Binding<Bool>, error: Binding<String?>) {
            self.isLoading = isLoading
            self.error = error
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("📱 WebView started loading")
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = true
                self.error.wrappedValue = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("📱 WebView finished loading successfully")
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed to load: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = false
                self.error.wrappedValue = "Failed to load feedback: \(error.localizedDescription)"
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = false
                self.error.wrappedValue = "Could not connect to feedback server. Please check your connection."
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation
            decisionHandler(.allow)
        }
    }
}

#Preview {
    let recording = SpeechRecording(
        speakerName: "Alice Smith",
        speakerPosition: "Prop 1",
        localFilePath: "/path/to/file.m4a",
        durationSeconds: 300,
        debateSession: nil
    )
    recording.feedbackUrl = "https://api.genalphai.com/feedback/view/22"
    recording.transcriptionStatus = .complete
    recording.feedbackStatus = .complete
    recording.updateAggregatedStatus()

    return NavigationStack {
        FeedbackDetailView(recording: recording)
    }
}
