import Foundation
import OSLog

/// Debug-only analytics provider that logs to console
class AnalyticsDebugger: AnalyticsProvider {
    private let logger = Logger(subsystem: "com.debatemateapp", category: "Analytics")

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        var logMessage = "📊 Event: \(eventName)"
        if let params = parameters {
            let paramString = params.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logMessage += " | Params: [\(paramString)]"
        }
        logger.info("\(logMessage)")
        print(logMessage) // Also print for easy viewing in Xcode console
    }

    func setUserProperty(_ value: String, forName name: String) {
        let message = "👤 User Property: \(name) = \(value)"
        logger.info("\(message)")
        print(message)
    }

    func setUserId(_ userId: String?) {
        let message = "🆔 User ID: \(userId ?? "nil")"
        logger.info("\(message)")
        print(message)
    }

    func logScreenView(_ screenName: String, screenClass: String) {
        let message = "📱 Screen View: \(screenName) (\(screenClass))"
        logger.info("\(message)")
        print(message)
    }

    func resetAnalyticsData() {
        let message = "🔄 Analytics data reset"
        logger.info("\(message)")
        print(message)
    }
}
