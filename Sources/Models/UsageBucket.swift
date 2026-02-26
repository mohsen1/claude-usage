import Foundation

struct UsageBucket: Codable, Sendable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    var percentage: Int {
        min(Int(utilization.rounded()), 100)
    }

    var timeUntilReset: String? {
        guard let date = resetsAtDate else { return nil }
        let remaining = date.timeIntervalSinceNow
        guard remaining > 0 else { return "now" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
