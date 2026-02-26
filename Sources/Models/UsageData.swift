import Foundation

struct UsageData: Codable, Sendable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let sevenDayCowork: UsageBucket?
    let sevenDayOauthApps: UsageBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayCowork = "seven_day_cowork"
        case sevenDayOauthApps = "seven_day_oauth_apps"
    }

    var sessionPercentage: Int {
        fiveHour?.percentage ?? 0
    }

    var weeklyPercentage: Int {
        sevenDay?.percentage ?? 0
    }
}
