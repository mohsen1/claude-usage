import Foundation

struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    var sessionKey: String
    var organizationId: String
    var organizationName: String
    var alias: String?
    let createdAt: Date

    var displayName: String {
        alias ?? organizationName
    }

    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}
