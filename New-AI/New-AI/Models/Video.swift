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
    let fileSize: Int64
    let duration: Double
    let resolution: String
    let status: String
    let processingMetadata: ProcessingMetadata
    
    struct ProcessingMetadata: Codable {
        let transcodingStatus: String
        let thumbnailStatus: String
        let transcriptStatus: String
        let summaryStatus: String
        let originalFileName: String
        let originalFileSize: Int64
        let contentType: String
        
        enum CodingKeys: String, CodingKey {
            case transcodingStatus = "transcodingStatus"
            case thumbnailStatus = "thumbnailStatus"
            case transcriptStatus = "transcriptStatus"
            case summaryStatus = "summaryStatus"
            case originalFileName = "originalFileName"
            case originalFileSize = "originalFileSize"
            case contentType = "contentType"
        }
    }
    
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
        case fileSize
        case duration
        case resolution
        case status
        case processingMetadata
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
        self.fileSize = 0
        self.duration = 0
        self.resolution = ""
        self.status = "processing"
        self.processingMetadata = ProcessingMetadata(
            transcodingStatus: "pending",
            thumbnailStatus: "pending",
            transcriptStatus: "pending",
            summaryStatus: "pending",
            originalFileName: "mock.mp4",
            originalFileSize: 0,
            contentType: "video/mp4"
        )
    }
} 