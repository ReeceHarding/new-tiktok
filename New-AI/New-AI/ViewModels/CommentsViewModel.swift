import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CommentsViewModel: ObservableObject {
    private let db = Firestore.firestore()
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchComments(for videoID: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("comments")
                .whereField("video_id", isEqualTo: videoID)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            let fetchedComments = snapshot.documents.compactMap { document -> Comment? in
                try? document.data(as: Comment.self)
            }
            
            self.comments = fetchedComments
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func addComment(videoID: String, text: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Comments", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let commentID = UUID().uuidString
        let comment = Comment(
            id: commentID,
            videoID: videoID,
            userID: user.uid,
            username: user.email ?? "unknown",
            text: text,
            timestamp: Date(),
            likes: 0,
            isLiked: false
        )
        
        try await db.collection("comments").document(commentID).setData(from: comment)
        
        // Update video comment count
        try await db.collection("videos").document(videoID).updateData([
            "comments": FieldValue.increment(Int64(1))
        ])
        
        // Refresh comments
        await fetchComments(for: videoID)
    }
    
    func likeComment(_ comment: Comment) async throws {
        try await db.collection("comments").document(comment.id).updateData([
            "likes": FieldValue.increment(Int64(1))
        ])
        await fetchComments(for: comment.videoID)
    }
} 