import Foundation
import SwiftUI
import UIKit

/// Backend analytics provider that sends events to custom API
class BackendAnalyticsProvider: AnalyticsProvider {

    private let session: URLSession
    private var eventQueue: [AnalyticsEventDTO] = []
    private let sessionId: String
    private let deviceId: String
    private var currentUserId: String?
    private var userType: String = "guest"
    private let baseURL: String

    // Batch configuration
    private let batchSize = 10
    private let flushInterval: TimeInterval = 30 // seconds
    private var flushTimer: Timer?

    init(deviceId: String) {
        self.deviceId = deviceId
        self.sessionId = UUID().uuidString
        self.baseURL = Constants.API.baseURL

        // Configure URLSession for analytics
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // Short timeout for analytics
        self.session = URLSession(configuration: config)

        // Start periodic flush timer
        startFlushTimer()

        // Flush on app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        // Flush on app backgrounding
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        flushTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        let event = AnalyticsEventDTO(
            event_name: eventName,
            user_id: currentUserId,
            session_id: sessionId,
            device_id: deviceId,
            user_type: userType,
            screen_name: nil,
            debate_id: parameters?["debate_id"] as? String,
            speech_id: parameters?["speech_id"] as? Int,
            student_id: parameters?["student_id"] as? String,
            class_session_id: parameters?["class_session_id"] as? String,
            properties: parameters,
            app_version: getAppVersion(),
            os_version: getOSVersion(),
            device_model: getDeviceModel(),
            client_timestamp: ISO8601DateFormatter().string(from: Date())
        )

        eventQueue.append(event)

        // Flush if batch size reached
        if eventQueue.count >= batchSize {
            flush()
        }
    }

    func setUserProperty(_ value: String, forName name: String) {
        // Store user properties for future events
        if name == "user_type" {
            userType = value
        }
    }

    func setUserId(_ userId: String?) {
        currentUserId = userId
    }

    func logScreenView(_ screenName: String, screenClass: String) {
        logEvent("screen_view", parameters: [
            "screen_name": screenName,
            "screen_class": screenClass
        ])
    }

    func resetAnalyticsData() {
        currentUserId = nil
        userType = "guest"
        flush() // Flush remaining events before reset
    }

    // MARK: - Flushing

    private func flush() {
        guard !eventQueue.isEmpty else { return }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        Task {
            await sendEvents(eventsToSend)
        }
    }

    @objc private func flushTimerFired() {
        flush()
    }

    @objc private func applicationWillTerminate() {
        flush()
    }

    @objc private func applicationDidEnterBackground() {
        flush()
    }

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(
            withTimeInterval: flushInterval,
            repeats: true
        ) { [weak self] _ in
            self?.flushTimerFired()
        }
    }

    private func sendEvents(_ events: [AnalyticsEventDTO]) async {
        let request = LogAnalyticsEventRequest(events: events)

        guard let url = URL(string: "\(baseURL)/analytics/events") else {
            print("❌ Analytics: Invalid URL")
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available (optional for analytics)
        if let token = KeychainService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)

            let (_, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Analytics: Invalid response")
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                #if DEBUG
                print("✅ Analytics: Sent \(events.count) events successfully")
                #endif
            } else {
                print("⚠️ Analytics: Server returned status \(httpResponse.statusCode)")
                // Re-queue failed events (with limit to prevent memory issues)
                if eventQueue.count < 100 {
                    eventQueue.insert(contentsOf: events, at: 0)
                }
            }
        } catch {
            print("❌ Analytics: Error sending events: \(error.localizedDescription)")
            // Re-queue failed events (with limit)
            if eventQueue.count < 100 {
                eventQueue.insert(contentsOf: events, at: 0)
            }
        }
    }

    // MARK: - Device Info

    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - DTOs

struct AnalyticsEventDTO: Encodable {
    let event_name: String
    let user_id: String?
    let session_id: String
    let device_id: String
    let user_type: String
    let screen_name: String?
    let debate_id: String?
    let speech_id: Int?
    let student_id: String?
    let class_session_id: String?
    let properties: [String: Any]?
    let app_version: String?
    let os_version: String?
    let device_model: String?
    let client_timestamp: String

    enum CodingKeys: String, CodingKey {
        case event_name, user_id, session_id, device_id, user_type
        case screen_name, debate_id, speech_id, student_id, class_session_id
        case properties, app_version, os_version, device_model, client_timestamp
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event_name, forKey: .event_name)
        try container.encodeIfPresent(user_id, forKey: .user_id)
        try container.encode(session_id, forKey: .session_id)
        try container.encode(device_id, forKey: .device_id)
        try container.encode(user_type, forKey: .user_type)
        try container.encodeIfPresent(screen_name, forKey: .screen_name)
        try container.encodeIfPresent(debate_id, forKey: .debate_id)
        try container.encodeIfPresent(speech_id, forKey: .speech_id)
        try container.encodeIfPresent(student_id, forKey: .student_id)
        try container.encodeIfPresent(class_session_id, forKey: .class_session_id)

        // Encode properties as JSON
        if let props = properties {
            let jsonData = try JSONSerialization.data(withJSONObject: props, options: [])
            let jsonObject = try JSONDecoder().decode([String: AnyCodable].self, from: jsonData)
            try container.encode(jsonObject, forKey: .properties)
        } else {
            try container.encode([String: AnyCodable](), forKey: .properties)
        }

        try container.encodeIfPresent(app_version, forKey: .app_version)
        try container.encodeIfPresent(os_version, forKey: .os_version)
        try container.encodeIfPresent(device_model, forKey: .device_model)
        try container.encode(client_timestamp, forKey: .client_timestamp)
    }
}

struct LogAnalyticsEventRequest: Encodable {
    let events: [AnalyticsEventDTO]
}

struct LogAnalyticsEventResponse: Codable {
    let success: Bool
    let events_logged: Int
    let message: String?
}

// Helper to encode Any values in Codable
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
}
