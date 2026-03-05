import Foundation

/// Protocol for analytics providers (Firebase, custom backend, etc.)
protocol AnalyticsProvider {
    func logEvent(_ eventName: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String, forName name: String)
    func setUserId(_ userId: String?)
    func logScreenView(_ screenName: String, screenClass: String)
    func resetAnalyticsData()
}

/// Extension with default implementations
extension AnalyticsProvider {
    func logEvent(_ eventName: String) {
        logEvent(eventName, parameters: nil)
    }
}
