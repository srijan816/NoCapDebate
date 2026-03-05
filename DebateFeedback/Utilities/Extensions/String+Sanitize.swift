//
//  String+Sanitize.swift
//  DebateFeedback
//
//

import Foundation

extension String {
    /// Sanitizes a string for use in filenames by removing/replacing invalid characters
    func sanitizedForFilename() -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = self.components(separatedBy: invalidCharacters).joined(separator: "_")
        return sanitized
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
    }

    /// Validates if string is a valid motion
    var isValidMotion: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= Constants.Validation.minimumMotionLength &&
               trimmed.count <= Constants.Validation.maximumMotionLength
    }

    /// Validates if string is a valid speaker name
    var isValidSpeakerName: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= Constants.Validation.minimumSpeakerName &&
               trimmed.count <= Constants.Validation.maximumSpeakerName
    }
}
