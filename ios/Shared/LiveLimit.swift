import Foundation
import ActivityKit
import DeviceActivity

enum LiveLimit {
    static let prefix = "live."

    static func usedMinutes(for limit: Int) -> [Int] {
        guard limit >= 20 else { return limit >= 10 ? [limit - 5] : [] }
        let start = limit / 2
        let step = max(5, ((limit - start) / 10 + 4) / 5 * 5)
        var marks = Array(stride(from: start, to: limit - 5, by: step))
        marks.append(limit - 5)
        return Array(Set(marks)).sorted()
    }

    static func events(for group: LimitGroup) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for used in usedMinutes(for: group.minutes) {
            events[DeviceActivityEvent.Name(rawValue: prefix + String(used))] = group.event(after: used)
        }
        return events
    }

    static func usedMinutes(from event: DeviceActivityEvent.Name) -> Int? {
        guard event.rawValue.hasPrefix(prefix) else { return nil }
        return Int(event.rawValue.dropFirst(prefix.count))
    }

    static var relayURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "LiveRelayURL") as? String).flatMap(URL.init(string:))
    }

    static func send(_ kind: String, group: LimitGroup, remaining: Int) {
        guard let url = relayURL, let start = SharedStorage.livePushToStartToken else { return }
        var body: [String: Any] = [
            "kind": kind,
            "startToken": start,
            "groupID": group.id.uuidString,
            "name": group.name,
            "remaining": remaining,
            "limit": group.minutes,
        ]
        if let update = SharedStorage.liveUpdateToken(for: group.id) { body["updateToken"] = update }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 4
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in done.signal() }.resume()
        _ = done.wait(timeout: .now() + 5)
    }

    @MainActor
    static func observeTokens() {
        Task {
            for await token in Activity<LiveLimitAttributes>.pushToStartTokenUpdates {
                SharedStorage.livePushToStartToken = token.map { String(format: "%02x", $0) }.joined()
            }
        }
        Task {
            for await activity in Activity<LiveLimitAttributes>.activityUpdates {
                let id = activity.attributes.groupID
                Task {
                    for await token in activity.pushTokenUpdates {
                        SharedStorage.setLiveUpdateToken(token.map { String(format: "%02x", $0) }.joined(), for: id)
                    }
                }
            }
        }
    }
}
