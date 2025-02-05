import Foundation
import FirebaseFirestore

struct Video: Identifiable, Codable, Equatable {
    let id: String
    let uploaderID: String
    let title: String
    let description: String
    let videoURL: String
    let thumbnailURL: String?
    let status: String
    let uploadDate: Date
    let duration: Double
    let resolution: String
    let fileSize: Int64
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let totalWatchTime: Double
    let averageWatchTime: Double
    let completionRate: Double
    let rewatchRate: Double
    let transcript: String
    let summary: String
    let engagementScore: Double
    let searchKeywords: [String]
    let tags: [String]
    let processingMetadata: ProcessingMetadata
    
    struct ProcessingMetadata: Codable {
        let contentType: String
        let originalFileName: String
        let originalFileSize: Int64
        let processingStatus: String
        let summaryStatus: String
        let thumbnailStatus: String
        let transcodingStatus: String
        let transcriptStatus: String
        let uploadAttempt: Int
        let uploadTimestamp: Date
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case uploaderID
        case title
        case description
        case videoURL
        case thumbnailURL
        case status
        case uploadDate
        case duration
        case resolution
        case fileSize
        case viewCount
        case likeCount
        case commentCount
        case totalWatchTime
        case averageWatchTime
        case completionRate
        case rewatchRate
        case transcript
        case summary
        case engagementScore
        case searchKeywords
        case tags
        case processingMetadata
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
        let normalizedLikes = likeCount > 0 ? min(log10(Double(likeCount)) / 5.0, 1.0) : 0
        
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
        self.uploaderID = "mock_user"
        self.title = "Mock Title"
        self.description = "Mock Description"
        self.videoURL = "mock_url"
        self.thumbnailURL = nil
        self.status = "processing"
        self.uploadDate = Date()
        self.duration = 0
        self.resolution = ""
        self.fileSize = 0
        self.viewCount = 0
        self.likeCount = 0
        self.commentCount = comments
        self.totalWatchTime = 0
        self.averageWatchTime = 0
        self.completionRate = 0
        self.rewatchRate = 0
        self.transcript = ""
        self.summary = ""
        self.engagementScore = 0
        self.searchKeywords = []
        self.tags = []
        self.processingMetadata = ProcessingMetadata(
            contentType: "video/mp4",
            originalFileName: "mock.mp4",
            originalFileSize: 0,
            processingStatus: "pending",
            summaryStatus: "pending",
            thumbnailStatus: "pending",
            transcodingStatus: "pending",
            transcriptStatus: "pending",
            uploadAttempt: 1,
            uploadTimestamp: Date()
        )
    }
    
    static func == (lhs: Video, rhs: Video) -> Bool {
        return lhs.id == rhs.id
    }
} 