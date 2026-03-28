import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    var pseudo: String
    var authToken: String
    var avatarIndex: Int

    init(pseudo: String, authToken: String, avatarIndex: Int) {
        self.id = UUID().uuidString
        self.pseudo = pseudo
        self.authToken = authToken
        self.avatarIndex = avatarIndex
    }

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool { lhs.id == rhs.id }
}
