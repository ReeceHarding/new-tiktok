import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    let id: String
    let videoID: String
    let userID: String
    let username: String
    let text: String
    let timestamp: Date
    var likes: Int
    var isLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case userID = "user_id"
        case username
        case text
        case timestamp
        case likes
        case isLiked = "is_liked"
    }
} 