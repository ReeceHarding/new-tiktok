import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    let userID: String
    var text: String
    let timestamp: Date
    var edited: Bool
    var editTimestamp: Date?
    var likeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID
        case text
        case timestamp
        case edited
        case editTimestamp
        case likeCount
    }
    
    init(id: String? = nil, userID: String, text: String, timestamp: Date = Date(), edited: Bool = false, editTimestamp: Date? = nil, likeCount: Int = 0) {
        self.id = id
        self.userID = userID
        self.text = text
        self.timestamp = timestamp
        self.edited = edited
        self.editTimestamp = editTimestamp
        self.likeCount = likeCount
    }
} 