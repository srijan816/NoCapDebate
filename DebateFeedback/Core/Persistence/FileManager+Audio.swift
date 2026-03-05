//
//  FileManager+Audio.swift
//  DebateFeedback
//
//

import Foundation

extension FileManager {
    /// Returns the URL for the audio recordings directory
    static var audioRecordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documentsPath.appendingPathComponent(Constants.Files.audioDirectory)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioDir.path) {
            try? FileManager.default.createDirectory(
                at: audioDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return audioDir
    }

    /// Generates a unique filename for an audio recording
    static func generateAudioFilename(
        debateId: String,
        speakerName: String,
        position: String
    ) -> String {
        let timestamp = Date().iso8601String
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")
        let sanitizedName = speakerName.sanitizedForFilename()
        let sanitizedPosition = position.sanitizedForFilename()

        return "\(debateId)_\(sanitizedName)_\(sanitizedPosition)_\(timestamp).\(Constants.Audio.fileExtension)"
    }

    /// Returns the full URL for a recording file
    static func audioFileURL(filename: String) -> URL {
        audioRecordingsDirectory.appendingPathComponent(filename)
    }

    /// Deletes a recording file
    static func deleteAudioFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.removeItem(at: url)
    }

    /// Cleans up old recordings (older than configured days)
    static func cleanupOldRecordings() {
        let audioDir = audioRecordingsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: audioDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoffDate = Date().addingTimeInterval(-TimeInterval(Constants.Files.maxLocalStorageDays * 24 * 60 * 60))

        for file in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            if creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Returns the size of a file in bytes
    static func fileSize(at path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// Resolves the current absolute path for a file, handling iOS Sandbox Container rotation.
    ///
    /// The iOS app container path changes on every update or reinstall (UUID rotation).
    /// Stored absolute paths become invalid. This method attempts to find the file
    /// relative to the current Documents directory if the absolute path fails.
    ///
    /// - Parameter savedPath: The absolute path string stored in the database.
    /// - Returns: A valid URL if the file is found; otherwise nil.
    func resolveCurrentPath(for savedPath: String) -> URL? {
        let absoluteURL = URL(fileURLWithPath: savedPath)
        
        // 1. Try the saved path directly (fast path, works if container hasn't rotated)
        if fileExists(atPath: absoluteURL.path) {
            return absoluteURL
        }
        
        // 2. Try resolving relative to the current Documents directory
        // Extract the filename from the saved path
        let fileName = absoluteURL.lastPathComponent
        
        // Get the current valid Documents directory
        let currentDocuments = urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Construct the new dynamic path
        // Try in "Recordings" (Constants.Files.audioDirectory) first as that is default
        let recordingsURL = currentDocuments.appendingPathComponent(Constants.Files.audioDirectory).appendingPathComponent(fileName)
        if fileExists(atPath: recordingsURL.path) {
            return recordingsURL
        }

        // Try directly in Documents (just in case)
        let rootDynamicURL = currentDocuments.appendingPathComponent(fileName)
        if fileExists(atPath: rootDynamicURL.path) {
            return rootDynamicURL
        }
        
        return nil
    }
}
