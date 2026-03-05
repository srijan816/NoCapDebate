//
//  TimerTextView.swift
//  DebateFeedback
//
//  Optimized view for displaying the timer text to avoid full view redraws
//

import SwiftUI

struct TimerTextView: View {
    let viewModel: TimerViewModel
    
    var body: some View {
        Text(viewModel.formattedTime)
            .font(.system(size: Constants.timerFontSize, weight: .bold, design: .monospaced))
            .foregroundColor(viewModel.isOvertime ? .red : Constants.Colors.textPrimary)
            .accessibilityLabel("Timer")
            .accessibilityValue("\(viewModel.formattedTime)\(viewModel.isOvertime ? ", overtime" : "")")
            .onChange(of: viewModel.elapsedTime) { _, _ in
                viewModel.checkAndFireWarnings()
            }
    }
}
