import SwiftUI
import PhotosUI
import AVKit
import FirebaseAuth
import UniformTypeIdentifiers
import os.log

struct VideoUploadView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedVideoURL: URL? = nil
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var caption: String = ""
    @State private var showPreview = false
    @State private var player: AVPlayer? = nil
    
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoUploadView")
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Video Preview or Upload Button
                        Group {
                            if let player = player {
                                VideoPlayer(player: player)
                                    .frame(height: 400)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            } else {
                                PhotosPicker(selection: $selectedItem,
                                           matching: .videos,
                                           photoLibrary: .shared()) {
                                    uploadPlaceholder
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        
                        if player != nil {
                            // Caption TextField
                            TextField("Add a caption...", text: $caption)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            // Upload Button
                            Button(action: {
                                Task {
                                    await uploadVideo()
                                }
                            }) {
                                HStack {
                                    if isUploading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    }
                                    Text(isUploading ? "Uploading..." : "Post")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(25)
                            }
                            .disabled(isUploading)
                            .padding(.horizontal)
                            
                            if isUploading {
                                ProgressView(value: uploadProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Messages
                        Group {
                            if let error = errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            if let success = successMessage {
                                Text(success)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("New Video")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedItem) { newItem in
                if let newItem = newItem {
                    loadVideo(from: newItem)
                }
            }
        }
    }
    
    private var uploadPlaceholder: some View {
        VStack(spacing: 15) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.white)
            
            Text("Tap to select a video")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("MP4, MOV up to 3 minutes")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func loadVideo(from item: PhotosPickerItem) {
        logger.notice("🎥 Starting video load from PhotosPickerItem")
        
        Task {
            do {
                logger.debug("📥 Loading video data")
                guard let videoData = try await item.loadTransferable(type: Data.self) else {
                    logger.error("❌ Failed to load video data from picker item")
                    throw URLError(.badURL)
                }
                
                // Check file size (500MB limit)
                let maxSize = 500 * 1024 * 1024 // 500MB in bytes
                let videoSize = videoData.count
                logger.debug("📊 Video size: \(videoSize) bytes (max: \(maxSize) bytes)")
                
                guard videoSize <= maxSize else {
                    logger.error("❌ Video size (\(videoSize) bytes) exceeds limit of \(maxSize) bytes")
                    throw NSError(domain: "VideoUpload", code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "Video size exceeds 500MB limit"])
                }
                
                // Create temp file with proper extension
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                logger.debug("📂 Creating temporary file at: \(tempURL.path)")
                
                try videoData.write(to: tempURL)
                logger.debug("✅ Video data written to temporary file")
                
                // Validate video duration
                logger.debug("⏱️ Checking video duration")
                let asset = AVAsset(url: tempURL)
                let duration = try await asset.load(.duration)
                logger.debug("⏱️ Video duration: \(duration.seconds) seconds")
                
                guard duration.seconds <= 180 else { // 3 minutes max
                    logger.error("❌ Video duration (\(duration.seconds) seconds) exceeds limit of 180 seconds")
                    throw NSError(domain: "VideoUpload", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Video duration exceeds 3 minutes"])
                }
                
                await MainActor.run {
                    logger.notice("✅ Video loaded successfully")
                    logger.debug("📊 Video stats - Size: \(videoSize) bytes, Duration: \(duration.seconds) seconds")
                    self.selectedVideoURL = tempURL
                    self.player = AVPlayer(url: tempURL)
                    self.player?.play()
                    self.errorMessage = nil
                }
            } catch {
                logger.error("❌ Video load failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "Failed to load video: \(error.localizedDescription)"
                    self.selectedVideoURL = nil
                    self.player = nil
                }
            }
        }
    }
    
    private func uploadVideo() async {
        logger.notice("🚀 Starting video upload process")
        
        guard let videoURL = selectedVideoURL else {
            logger.error("❌ No video URL available for upload")
            errorMessage = "No video selected."
            return
        }
        
        guard !caption.isEmpty else {
            logger.error("❌ No caption provided")
            errorMessage = "Please add a caption."
            return
        }
        
        logger.debug("📝 Upload parameters - Caption: \(caption), Video URL: \(videoURL.path)")
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadProgress = 0.0
        
        do {
            logger.notice("📤 Initiating upload to Firebase")
            let downloadURL = try await VideoUploader.uploadVideo(
                fileURL: videoURL,
                caption: caption,
                progressHandler: { progress in
                    Task { @MainActor in
                        self.uploadProgress = progress
                        logger.debug("📊 Upload progress update: \(Int(progress * 100))%")
                    }
                }
            )
            
            logger.notice("✅ Upload completed successfully")
            logger.debug("🔗 Download URL: \(downloadURL)")
            
            await MainActor.run {
                successMessage = "Video uploaded successfully!"
                isUploading = false
                uploadProgress = 1.0
                // Reset the view after a successful upload
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    logger.debug("🔄 Resetting view state after successful upload")
                    self.selectedItem = nil
                    self.selectedVideoURL = nil
                    self.player = nil
                    self.caption = ""
                    self.successMessage = nil
                    self.uploadProgress = 0.0
                }
            }
        } catch VideoUploadError.userNotAuthenticated {
            logger.error("❌ Upload failed: User not authenticated")
            await MainActor.run {
                errorMessage = "Please sign in to upload videos."
                isUploading = false
            }
        } catch VideoUploadError.invalidURL {
            logger.error("❌ Upload failed: Invalid URL")
            await MainActor.run {
                errorMessage = "The selected video file is no longer accessible."
                isUploading = false
            }
        } catch VideoUploadError.retryExhausted {
            logger.error("❌ Upload failed: Retry attempts exhausted")
            await MainActor.run {
                errorMessage = "Upload failed after multiple attempts. Please try again."
                isUploading = false
            }
        } catch VideoUploadError.uploadFailed(let message) {
            logger.error("❌ Upload failed with message: \(message)")
            await MainActor.run {
                errorMessage = "Upload failed: \(message)"
                isUploading = false
            }
        } catch VideoUploadError.metadataError(let message) {
            logger.error("❌ Metadata error: \(message)")
            await MainActor.run {
                errorMessage = "Metadata error: \(message)"
                isUploading = false
            }
        } catch VideoUploadError.firestoreError(let message) {
            logger.error("❌ Firestore error: \(message)")
            await MainActor.run {
                errorMessage = "Database error: \(message)"
                isUploading = false
            }
        } catch {
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                isUploading = false
            }
        }
    }
}

#Preview {
    VideoUploadView()
} 