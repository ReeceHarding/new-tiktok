import Foundation
import FirebaseFirestore

struct Video: Identifiable, Codable, Equatable {
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
    let totalWatchTime: Double
    let averageWatchTime: Double
    let completionRate: Double
    let rewatchRate: Double
    let transcript: String
    let summary: String
    let processingMetadata: ProcessingMetadata
    let engagementScore: Double
    let searchKeywords: [String]
    
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
        case totalWatchTime
        case averageWatchTime
        case completionRate
        case rewatchRate
        case transcript
        case summary
        case processingMetadata
        case engagementScore
        case searchKeywords
    }
    
    // Computed property for local debugging: calculates a simple engagement score
    var computedEngagementScore: Double {
        // Weights for different engagement factors (these can be adjusted based on analytics)
        let watchTimeWeight = 0.4
        let completionRateWeight = 0.3
        let likesWeight = 0.2
        let rewatchWeight = 0.1
        
        // Normalize watch time ratio (total watch time / duration)
        let watchTimeRatio = duration > 0 ? min(totalWatchTime / duration, 1.0) : 0
        
        // Normalize likes (using a log scale to prevent extreme values from dominating)
        let normalizedLikes = likes > 0 ? min(log10(Double(likes)) / 5.0, 1.0) : 0
        
        // Calculate weighted score
        let score = (watchTimeWeight * watchTimeRatio) +
                   (completionRateWeight * completionRate) +
                   (likesWeight * normalizedLikes) +
                   (rewatchWeight * rewatchRate)
        
        return min(score, 1.0) // Ensure score is between 0 and 1
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
        self.totalWatchTime = 0
        self.averageWatchTime = 0
        self.completionRate = 0
        self.rewatchRate = 0
        self.transcript = ""
        self.summary = ""
        self.engagementScore = 0
        self.searchKeywords = []
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
    
    static func == (lhs: Video, rhs: Video) -> Bool {
        return lhs.id == rhs.id
    }
} 