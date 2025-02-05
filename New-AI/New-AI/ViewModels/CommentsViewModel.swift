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
            let snapshot = try await db.collection("videos").document(videoID)
                .collection("comments")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var fetchedComments = snapshot.documents.compactMap { document -> Comment? in
                try? document.data(as: Comment.self)
            }
            
            // Fetch like status for each comment if user is signed in
            if let currentUserID = Auth.auth().currentUser?.uid {
                for i in 0..<fetchedComments.count {
                    let commentID = fetchedComments[i].id
                    let likeDoc = try? await db.collection("videos").document(videoID)
                        .collection("comments").document(commentID)
                        .collection("likes").document(currentUserID)
                        .getDocument()
                    
                    fetchedComments[i].isLiked = likeDoc?.exists ?? false
                }
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
        
        guard text.count <= 250 else {
            throw NSError(domain: "Comments", code: -1, userInfo: [NSLocalizedDescriptionKey: "Comment cannot exceed 250 characters"])
        }
        
        let commentID = UUID().uuidString
        let comment = Comment(
            id: commentID,
            videoID: videoID,
            userID: user.uid,
            username: user.email ?? "unknown",
            text: text,
            timestamp: Date(),
            likeCount: 0,
            edited: false,
            editTimestamp: nil
        )
        
        // Add comment to subcollection
        try await db.collection("videos").document(videoID)
            .collection("comments").document(commentID)
            .setData(from: comment)
        
        // Update video comment count
        try await db.collection("videos").document(videoID).updateData([
            "comment_count": FieldValue.increment(Int64(1))
        ])
        
        // Refresh comments
        await fetchComments(for: videoID)
    }
    
    func likeComment(_ comment: Comment) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Comments", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let commentRef = db.collection("videos").document(comment.videoID)
            .collection("comments").document(comment.id)
        let likeRef = commentRef.collection("likes").document(user.uid)
        
        let likeDoc = try await likeRef.getDocument()
        
        if likeDoc.exists {
            // Unlike
            try await likeRef.delete()
            try await commentRef.updateData([
                "like_count": FieldValue.increment(Int64(-1))
            ])
        } else {
            // Like
            try await likeRef.setData([
                "user_id": user.uid,
                "liked_at": FieldValue.serverTimestamp()
            ])
            try await commentRef.updateData([
                "like_count": FieldValue.increment(Int64(1))
            ])
        }
        
        await fetchComments(for: comment.videoID)
    }
    
    func editComment(_ comment: Comment, newText: String) async throws {
        guard let user = Auth.auth().currentUser, user.uid == comment.userID else {
            throw NSError(domain: "Comments", code: -1, userInfo: [NSLocalizedDescriptionKey: "You can only edit your own comments"])
        }
        
        guard newText.count <= 250 else {
            throw NSError(domain: "Comments", code: -1, userInfo: [NSLocalizedDescriptionKey: "Comment cannot exceed 250 characters"])
        }
        
        try await db.collection("videos").document(comment.videoID)
            .collection("comments").document(comment.id)
            .updateData([
                "text": newText,
                "edited": true,
                "edit_timestamp": FieldValue.serverTimestamp()
            ])
        
        await fetchComments(for: comment.videoID)
    }
} 