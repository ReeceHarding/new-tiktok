import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    let id: String
    let videoID: String
    let userID: String
    let username: String
    let text: String
    let timestamp: Date
    var likeCount: Int
    var edited: Bool
    var editTimestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case userID = "user_id"
        case username
        case text
        case timestamp
        case likeCount = "like_count"
        case edited
        case editTimestamp = "edit_timestamp"
    }
    
    var isLiked: Bool = false // Computed property, not stored in Firestore
} 