import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import os.log

enum VideoUploadError: Error {
    case userNotAuthenticated
    case uploadFailed(String)
    case invalidURL
    case retryExhausted
    case metadataError(String)
    case firestoreError(String)
}

class VideoUploader {
    private static let maxRetries = 3
    private static var currentUploadTask: StorageUploadTask?
    private static let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoUploader")
    
    static func uploadVideo(fileURL: URL, caption: String = "Untitled Video", progressHandler: @escaping (Double) -> Void) async throws -> String {
        logger.debug("📝 Starting upload process for file: \(fileURL.lastPathComponent)")
        logger.debug("🔍 Full file URL: \(fileURL.absoluteString)")
        logger.debug("📂 File path: \(fileURL.path)")
        
        // Ensure we have a valid file URL
        guard fileURL.isFileURL else {
            logger.error("❌ Invalid file URL format: \(fileURL.absoluteString)")
            throw VideoUploadError.invalidURL
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        logger.debug("📊 File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
        
        // Cancel any existing upload
        if let existingTask = currentUploadTask {
            logger.notice("⚠️ Cancelling existing upload task")
            existingTask.cancel()
        }
        
        // Verify user authentication
        guard let user = Auth.auth().currentUser else {
            logger.error("❌ User authentication failed - no current user")
            throw VideoUploadError.userNotAuthenticated
        }
        logger.debug("👤 User authenticated: \(user.uid)")
        logger.debug("👤 User email: \(user.email ?? "none")")
        logger.debug("👤 User display name: \(user.displayName ?? "none")")
        
        // Generate unique filename and video ID
        let videoId = UUID().uuidString.lowercased()
        let filename = "\(videoId).mp4"
        
        // Validate filename matches storage rules pattern
        let pattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\\.mp4$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) != nil else {
            logger.error("❌ Invalid filename format: \(filename)")
            throw VideoUploadError.uploadFailed("Invalid filename format")
        }
        
        let storageRef = Storage.storage().reference().child("videos/\(user.uid)/\(filename)")
        logger.debug("📂 Storage path: videos/\(user.uid)/\(filename)")
        logger.debug("🆔 Video ID: \(videoId)")
        
        // Verify file exists and is accessible
        guard FileManager.default.fileExists(atPath: fileURL.path),
              FileManager.default.isReadableFile(atPath: fileURL.path) else {
            logger.error("❌ File not found or not readable at path: \(fileURL.path)")
            throw VideoUploadError.invalidURL
        }
        
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                logger.notice("🔄 Starting upload attempt \(attempt) of \(maxRetries)")
                
                // Validate file type
                let fileExtension = fileURL.pathExtension.lowercased()
                logger.debug("🔍 File extension: \(fileExtension)")
                guard ["mp4", "mov"].contains(fileExtension) else {
                    logger.error("❌ Invalid file type: \(fileExtension)")
                    throw VideoUploadError.uploadFailed("Invalid file type. Only MP4 and MOV files are supported.")
                }
                
                // Create metadata with processing status
                let metadata = StorageMetadata()
                metadata.contentType = fileExtension == "mp4" ? "video/mp4" : "video/quicktime"
                metadata.customMetadata = [
                    "processingStatus": "pending",
                    "transcodingStatus": "pending",
                    "thumbnailStatus": "pending",
                    "transcriptStatus": "pending",
                    "summaryStatus": "pending",
                    "uploaderId": user.uid,
                    "videoId": videoId,
                    "uploadAttempt": String(attempt),
                    "timestamp": String(Date().timeIntervalSince1970)
                ]
                
                // Log detailed metadata
                logger.debug("""
                📋 Metadata prepared:
                - Content Type: \(metadata.contentType ?? "unknown")
                - Custom Metadata:
                  - Processing Status: \(metadata.customMetadata?["processingStatus"] ?? "")
                  - Uploader ID: \(metadata.customMetadata?["uploaderId"] ?? "")
                  - Video ID: \(metadata.customMetadata?["videoId"] ?? "")
                  - Upload Attempt: \(metadata.customMetadata?["uploadAttempt"] ?? "")
                  - Timestamp: \(metadata.customMetadata?["timestamp"] ?? "")
                """)
                
                // Log detailed validation information
                logger.debug("""
                🔒 Storage Rules Validation:
                - File Size: \(fileSize) bytes (max: \(500 * 1024 * 1024))
                - Content Type: \(metadata.contentType ?? "unknown")
                - Storage Path: videos/\(user.uid)/\(filename)
                - Filename Pattern: \((try? NSRegularExpression(pattern: pattern).firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) != nil) ?? false)
                - User Auth: \(Auth.auth().currentUser?.uid ?? "none") == \(user.uid)
                - Metadata Fields:
                  - processingStatus: \(metadata.customMetadata?["processingStatus"] ?? "missing")
                  - transcodingStatus: \(metadata.customMetadata?["transcodingStatus"] ?? "missing")
                  - thumbnailStatus: \(metadata.customMetadata?["thumbnailStatus"] ?? "missing")
                  - transcriptStatus: \(metadata.customMetadata?["transcriptStatus"] ?? "missing")
                  - summaryStatus: \(metadata.customMetadata?["summaryStatus"] ?? "missing")
                  - uploaderId: \(metadata.customMetadata?["uploaderId"] ?? "missing")
                  - videoId: \(metadata.customMetadata?["videoId"] ?? "missing")
                  - uploadAttempt: \(metadata.customMetadata?["uploadAttempt"] ?? "missing")
                  - timestamp: \(metadata.customMetadata?["timestamp"] ?? "missing")
                """)
                
                // Upload the file with progress tracking
                let uploadTask = storageRef.putFile(from: fileURL, metadata: metadata)
                currentUploadTask = uploadTask
                
                // Monitor upload progress
                _ = uploadTask.observe(.progress) { snapshot in
                    let totalBytes = Double(snapshot.progress?.totalUnitCount ?? 1)
                    let completedBytes = Double(snapshot.progress?.completedUnitCount ?? 0)
                    let percentComplete = totalBytes > 0 ? min(completedBytes / totalBytes, 1.0) : 0
                    progressHandler(percentComplete)
                    logger.debug("""
                    📊 Upload progress:
                    - Percentage: \(Int(percentComplete * 100))%
                    - Bytes: \(snapshot.progress?.completedUnitCount ?? 0)/\(snapshot.progress?.totalUnitCount ?? 1)
                    - MB: \(completedBytes / 1024.0 / 1024.0)/\(totalBytes / 1024.0 / 1024.0)
                    """)
                }
                
                // Wait for upload to complete and get snapshot
                let snapshot = try await withCheckedThrowingContinuation { continuation in
                    uploadTask.observe(.success) { snapshot in
                        continuation.resume(returning: snapshot)
                    }
                    uploadTask.observe(.failure) { snapshot in
                        if let error = snapshot.error {
                            logger.error("""
                            ❌ Upload failed:
                            - Error: \(error.localizedDescription)
                            - Error Code: \((error as NSError).code)
                            - Error Domain: \((error as NSError).domain)
                            - User Info: \((error as NSError).userInfo)
                            - Storage Error: \(StorageErrorCode(rawValue: (error as NSError).code)?.rawValue ?? -1)
                            - Storage Path: \(storageRef.fullPath)
                            - Auth Status: \(Auth.auth().currentUser?.uid ?? "none")
                            """)
                            continuation.resume(throwing: error)
                        }
                    }
                }
                logger.notice("✅ Upload task completed for attempt \(attempt)")
                
                // Add delay before metadata verification
                try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))  // 1 second delay
                
                // Verify upload success by checking metadata with detailed logging
                guard let uploadedMetadata = snapshot.metadata else {
                    logger.error("""
                    ❌ Metadata verification failed:
                    - Storage Path: \(storageRef.fullPath)
                    - Snapshot Status: \(snapshot.status.rawValue)
                    - Progress: \(snapshot.progress?.completedUnitCount ?? 0)/\(snapshot.progress?.totalUnitCount ?? 0)
                    - Error: \(snapshot.error?.localizedDescription ?? "No error details")
                    """)
                    throw VideoUploadError.metadataError("Failed to verify upload metadata - Snapshot status: \(snapshot.status.rawValue)")
                }
                
                logger.debug("📋 Successfully retrieved metadata")
                logger.debug("""
                📋 Uploaded file metadata:
                - Size: \(uploadedMetadata.size) bytes (\(Double(uploadedMetadata.size) / 1024.0 / 1024.0) MB)
                - Content Type: \(uploadedMetadata.contentType ?? "unknown")
                - Created: \(uploadedMetadata.timeCreated?.description ?? "unknown")
                - Updated: \(uploadedMetadata.updated?.description ?? "unknown")
                - MD5 Hash: \(uploadedMetadata.md5Hash ?? "unknown")
                - Storage Bucket: \(uploadedMetadata.bucket)
                - Full Path: \(uploadedMetadata.path ?? "unknown")
                - Name: \(uploadedMetadata.name ?? "unknown")
                """)
                
                // Get download URL with retry
                let downloadURL = try await withRetry(maxRetries: 3) {
                    try await storageRef.downloadURL()
                }
                logger.debug("🔗 Download URL obtained: \(downloadURL.absoluteString)")
                
                // Create Firestore document
                let db = Firestore.firestore()
                let videoData: [String: Any] = [
                    "id": videoId,
                    "uploaderID": user.uid,
                    "title": caption,
                    "description": "",
                    "tags": [],
                    "status": "processing",
                    "videoURL": downloadURL.absoluteString,
                    "thumbnailURL": "",
                    "uploadDate": FieldValue.serverTimestamp(),
                    "duration": 0,
                    "resolution": "",
                    "fileSize": uploadedMetadata.size,
                    "viewCount": 0,
                    "likeCount": 0,
                    "commentCount": 0,
                    "totalWatchTime": 0,
                    "averageWatchTime": 0,
                    "completionRate": 0,
                    "rewatchRate": 0,
                    "transcript": "",
                    "summary": "",
                    "engagementScore": 0,
                    "processingMetadata": [
                        "transcodingStatus": "pending",
                        "thumbnailStatus": "pending",
                        "transcriptStatus": "pending",
                        "summaryStatus": "pending",
                        "originalFileName": fileURL.lastPathComponent,
                        "originalFileSize": uploadedMetadata.size,
                        "contentType": uploadedMetadata.contentType ?? "video/mp4",
                        "uploadAttempt": attempt,
                        "uploadTimestamp": FieldValue.serverTimestamp(),
                        "processingStatus": "pending"
                    ],
                    "searchKeywords": []
                ]
                
                logger.notice("📝 Creating Firestore document for video: \(videoId)")
                logger.debug("""
                📋 Firestore data:
                - Uploader ID: \(videoData["uploaderID"] as? String ?? "")
                - Title: \(videoData["title"] as? String ?? "")
                - Status: \(videoData["status"] as? String ?? "")
                - Video URL: \(videoData["videoURL"] as? String ?? "")
                - File Size: \(videoData["fileSize"] as? Int64 ?? 0) bytes
                - Processing Metadata:
                  - Original File Name: \((videoData["processingMetadata"] as? [String: Any])?["originalFileName"] as? String ?? "")
                  - Content Type: \((videoData["processingMetadata"] as? [String: Any])?["contentType"] as? String ?? "")
                  - Upload Attempt: \((videoData["processingMetadata"] as? [String: Any])?["uploadAttempt"] as? Int ?? 0)
                """
                )
                
                do {
                    try await db.collection("videos").document(videoId).setData(videoData)
                    logger.notice("✅ Firestore document created successfully")
                    return downloadURL.absoluteString
                } catch {
                    logger.error("❌ Firestore document creation failed: \(error.localizedDescription)")
                    throw VideoUploadError.firestoreError(error.localizedDescription)
                }
                
            } catch {
                logger.error("""
                ❌ Upload attempt \(attempt) failed:
                - Error: \(error.localizedDescription)
                - Type: \(type(of: error))
                """
                )
                lastError = error
                
                if attempt == maxRetries {
                    logger.error("❌ All retry attempts exhausted")
                    throw VideoUploadError.retryExhausted
                }
                
                let backoffSeconds = pow(Double(2), Double(attempt))
                logger.notice("⏳ Waiting \(backoffSeconds) seconds before retry")
                try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
            }
        }
        
        logger.error("""
        ❌ Upload failed with error:
        - Description: \(lastError?.localizedDescription ?? "Unknown error")
        - Type: \(type(of: lastError ?? VideoUploadError.uploadFailed("Unknown")))
        """
        )
        throw VideoUploadError.uploadFailed(lastError?.localizedDescription ?? "Unknown error")
    }
    
    // Helper function to retry operations
    private static func withRetry<T>(maxRetries: Int = 3, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                logger.error("""
                ❌ Retry operation failed (attempt \(attempt)/\(maxRetries)):
                - Error: \(error.localizedDescription)
                - Type: \(type(of: error))
                """
                )
                if attempt == maxRetries { break }
                try await Task.sleep(nanoseconds: UInt64(pow(Double(2), Double(attempt)) * 1_000_000_000))
            }
        }
        throw lastError ?? VideoUploadError.retryExhausted
    }
} 