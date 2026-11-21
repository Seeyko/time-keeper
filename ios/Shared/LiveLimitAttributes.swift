import ActivityKit

struct LiveLimitAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var remaining: Int
        var limit: Int
    }

    var groupID: String
    var name: String
}
