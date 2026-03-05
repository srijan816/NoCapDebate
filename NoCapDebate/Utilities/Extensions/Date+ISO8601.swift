//
//  Date+ISO8601.swift
//  DebateFeedback
//
//

import Foundation

extension Date {
    /// Returns ISO8601 formatted string
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }

    /// Creates a Date from ISO8601 string
    static func from(iso8601String: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso8601String)
    }

    /// Returns formatted time string (HH:mm:ss)
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }

    /// Returns formatted date string (MMM dd, yyyy)
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

extension TimeInterval {
    /// Converts TimeInterval to MM:SS format
    func toMinutesSeconds() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Converts TimeInterval to HH:MM:SS format
    func toHoursMinutesSeconds() -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
