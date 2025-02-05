import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

enum VideoUploadError: Error {
    case userNotAuthenticated
    case uploadFailed(String)
    case invalidURL
}

class VideoUploader {
    static func uploadVideo(fileURL: URL) async throws -> String {
        // Verify user authentication
        guard let user = Auth.auth().currentUser else {
            throw VideoUploadError.userNotAuthenticated
        }
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).mp4"
        let storageRef = Storage.storage().reference().child("videos/\(user.uid)/\(filename)")
        
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            // Upload the file
            let _ = try await storageRef.putFile(from: fileURL, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await storageRef.downloadURL()
            
            // Create Firestore document
            let db = Firestore.firestore()
            let videoData: [String: Any] = [
                "userID": user.uid,
                "videoURL": downloadURL.absoluteString,
                "timestamp": FieldValue.serverTimestamp(),
                "likes": 0,
                "comments": 0,
                "caption": "",
                "status": "active"
            ]
            
            try await db.collection("videos").document().setData(videoData)
            
            return downloadURL.absoluteString
        } catch {
            throw VideoUploadError.uploadFailed(error.localizedDescription)
        }
    }
} 