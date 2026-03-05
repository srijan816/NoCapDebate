//
//  UploadRequest.swift
//  DebateFeedback
//
//  Created by Srijan on 12/29/25.
//

import Foundation
import SwiftData

@Model
final class UploadRequest {
    var id: UUID
    var fileURL: URL
    var metadata: [String: String] // SwiftData handles simple dictionaries better as string-string or data
    var createdAt: Date
    var attemptCount: Int
    var status: UploadStatus
    
    // We store metadata as JSON string or simpler types if strict types are needed, 
    // but for this implementation we'll serialize the complex metadata dictionary to Data
    var metadataJson: Data
    
    init(id: UUID, fileURL: URL, metadata: [String: Any], status: UploadStatus = .pending) {
        self.id = id
        self.fileURL = fileURL
        self.createdAt = Date()
        self.attemptCount = 0
        self.status = status
        
        // Serialize metadata to Data
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: []) {
            self.metadataJson = data
        } else {
            self.metadataJson = Data()
        }
        
        // Populate display metadata for potential UI (simplified)
        self.metadata = [:]
    }
    
    var decodedMetadata: [String: Any] {
        guard !metadataJson.isEmpty else { return [:] }
        do {
            if let dict = try JSONSerialization.jsonObject(with: metadataJson, options: []) as? [String: Any] {
                return dict
            }
        } catch {
            print("Failed to decode metadata: \(error)")
        }
        return [:]
    }
}
