import Foundation
import UIKit

@MainActor
enum Analytics {
    static let projectKey = "phc_qQ63EzFg4vBkdGSepYQcqxKSAAnMawqKZK6vz7XHqE59"
    static let feedbackSurvey = "01a2007f-1d8c-0000-e025-097a250cf0f2"

    enum FeedbackQuestion {
        static let topic = "cd1b5288-cce3-4599-b6a4-7bbf42540e06"
        static let message = "fff741fd-0d01-4388-9ac3-4efe0fa106a7"
        static let email = "03f75b13-97ff-4059-a247-2ca18a660391"
    }

    private static let endpoint = URL(string: "https://eu.i.posthog.com/i/v0/e/")!
    private static let enabledKey = "analytics.enabled.v1"
    private static let idKey = "analytics.id.v1"
    private static let muted = ["-demo", "-onboarding", "-paywall"].contains(where: ProcessInfo.processInfo.arguments.contains)

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue { UserDefaults.standard.removeObject(forKey: idKey) }
        }
    }

    static var id: String {
        if let id = UserDefaults.standard.string(forKey: idKey) { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: idKey)
        return id
    }

    static var channel: String {
        #if DEBUG
        "debug"
        #else
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "testflight" : "app_store"
        #endif
    }

    static func capture(_ event: String, _ properties: [String: Any] = [:], person: [String: Any] = [:]) {
        guard enabled, !muted else { return }
        var props = properties
        props["canal"] = channel
        props["version_app"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        props["$os"] = "iOS"
        props["$os_version"] = UIDevice.current.systemVersion
        props["$lib"] = "time-keeper"
        props["$process_person_profile"] = true
        if !person.isEmpty { props["$set"] = person }
        send(event: event, distinctID: id, properties: props)
    }

    static func sendFeedback(topic: String, message: String, email: String?) async -> Bool {
        guard !muted else { return true }
        var props: [String: Any] = [
            "$survey_id": feedbackSurvey,
            "$survey_submission_id": UUID().uuidString.lowercased(),
            "$survey_completed": true,
            "$survey_response_\(FeedbackQuestion.topic)": topic,
            "$survey_response_\(FeedbackQuestion.message)": String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(3000)),
            "canal": channel,
            "version_app": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            "ios": UIDevice.current.systemVersion,
        ]
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            props["$survey_response_\(FeedbackQuestion.email)"] = String(email.prefix(200))
        }
        let distinct = enabled ? id : UUID().uuidString.lowercased()
        guard let request = request(event: "survey sent", distinctID: distinct, properties: props),
              let (_, response) = try? await URLSession(configuration: .ephemeral).data(for: request),
              let code = (response as? HTTPURLResponse)?.statusCode else { return false }
        return (200..<300).contains(code)
    }

    private static func send(event: String, distinctID: String, properties: [String: Any]) {
        guard let request = request(event: event, distinctID: distinctID, properties: properties) else { return }
        URLSession(configuration: .ephemeral).dataTask(with: request).resume()
    }

    private static func request(event: String, distinctID: String, properties: [String: Any]) -> URLRequest? {
        let body: [String: Any] = [
            "api_key": projectKey,
            "event": event,
            "distinct_id": distinctID,
            "properties": properties,
            "timestamp": ISO8601DateFormatter().string(from: .now),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return request
    }
}
