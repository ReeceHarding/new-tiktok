import Foundation
import FirebaseFirestore
import FirebaseAuth
import os.log

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private let videoID: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "New-AI", category: "CommentsViewModel")
    private var listenerRegistration: ListenerRegistration?
    
    init(videoID: String) {
        self.videoID = videoID
        setupCommentsListener()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    private func setupCommentsListener() {
        listenerRegistration?.remove()
        
        let commentsRef = db.collection("videos").document(videoID).collection("comments")
            .order(by: "timestamp", descending: true)
        
        listenerRegistration = commentsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Error listening for comments: \(error.localizedDescription)")
                self.error = error
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.logger.error("No documents in snapshot")
                return
            }
            
            self.comments = documents.compactMap { document -> Comment? in
                do {
                    return try document.data(as: Comment.self)
                } catch {
                    self.logger.error("Error decoding comment: \(error.localizedDescription)")
                    return nil
                }
            }
        }
    }
    
    func addComment(text: String) async throws {
        isSubmitting = true
        defer { isSubmitting = false }
        
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let batch = db.batch()
        
        // Create comment document reference
        let commentsRef = db.collection("videos").document(videoID).collection("comments")
        let newCommentRef = commentsRef.document()
        
        let comment = Comment(
            id: newCommentRef.documentID,
            userID: userID,
            text: text
        )
        
        // Set comment data
        try batch.setData(from: comment, forDocument: newCommentRef)
        
        // Update video's comment count
        let videoRef = db.collection("videos").document(videoID)
        batch.updateData([
            "commentCount": FieldValue.increment(Int64(1))
        ], forDocument: videoRef)
        
        // Commit the batch
        try await batch.commit()
        
        // Update local state
        comments.insert(comment, at: 0)
    }
    
    func toggleLike(for comment: Comment) async throws {
        guard let userID = Auth.auth().currentUser?.uid,
              let commentID = comment.id else { return }
        
        let likesRef = db.collection("videos").document(videoID)
            .collection("comments").document(commentID)
            .collection("likes")
        
        let likeDoc = likesRef.document(userID)
        let commentRef = db.collection("videos").document(videoID)
            .collection("comments").document(commentID)
        
        let likeSnapshot = try await likeDoc.getDocument()
        
        if likeSnapshot.exists {
            // Unlike
            _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                transaction.deleteDocument(likeDoc)
                transaction.updateData([
                    "likeCount": FieldValue.increment(Int64(-1))
                ], forDocument: commentRef)
                return nil
            })
            
            if let index = comments.firstIndex(where: { $0.id == commentID }) {
                comments[index].likeCount -= 1
            }
        } else {
            // Like
            _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                transaction.setData([
                    "userID": userID,
                    "likedAt": FieldValue.serverTimestamp()
                ], forDocument: likeDoc)
                
                transaction.updateData([
                    "likeCount": FieldValue.increment(Int64(1))
                ], forDocument: commentRef)
                return nil
            })
            
            if let index = comments.firstIndex(where: { $0.id == commentID }) {
                comments[index].likeCount += 1
            }
        }
    }
    
    func deleteComment(_ comment: Comment) async throws {
        guard let userID = Auth.auth().currentUser?.uid,
              userID == comment.userID,
              let commentID = comment.id else { return }
        
        let batch = db.batch()
        
        // Delete comment document
        let commentRef = db.collection("videos").document(videoID)
            .collection("comments").document(commentID)
        batch.deleteDocument(commentRef)
        
        // Update video's comment count
        let videoRef = db.collection("videos").document(videoID)
        batch.updateData([
            "commentCount": FieldValue.increment(Int64(-1))
        ], forDocument: videoRef)
        
        // Commit the batch
        try await batch.commit()
        
        // Update local state
        comments.removeAll(where: { $0.id == commentID })
    }
    
    func editComment(_ comment: Comment, newText: String) async throws {
        guard let userID = Auth.auth().currentUser?.uid,
              userID == comment.userID,
              let commentID = comment.id else { return }
        
        let commentRef = db.collection("videos").document(videoID)
            .collection("comments").document(commentID)
        
        let updateData: [String: Any] = [
            "text": newText,
            "edited": true,
            "editTimestamp": FieldValue.serverTimestamp()
        ]
        
        try await commentRef.updateData(updateData)
        
        if let index = comments.firstIndex(where: { $0.id == commentID }) {
            var updatedComment = comments[index]
            updatedComment.text = newText
            updatedComment.edited = true
            updatedComment.editTimestamp = Date()
            comments[index] = updatedComment
        }
    }
} 