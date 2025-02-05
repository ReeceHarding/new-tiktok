import Foundation
import FirebaseFirestore

struct Video: Identifiable, Codable {
    let id: String
    let userID: String
    let username: String
    let caption: String
    let videoURL: String
    let thumbnailURL: String?
    var likes: Int
    var comments: Int
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case username
        case caption
        case videoURL = "video_url"
        case thumbnailURL = "thumbnail_url"
        case likes
        case comments
        case timestamp
    }
    
    // Convenience initializer for mock data
    init(mockWithComments comments: Int) {
        self.id = UUID().uuidString
        self.userID = "mock_user"
        self.username = "mock_username"
        self.caption = "Mock Caption"
        self.videoURL = "mock_url"
        self.thumbnailURL = nil
        self.likes = 0
        self.comments = comments
        self.timestamp = Date()
    }
} 