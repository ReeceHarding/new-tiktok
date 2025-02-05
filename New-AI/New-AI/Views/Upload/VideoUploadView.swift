import SwiftUI
import PhotosUI
import AVKit
import FirebaseAuth
import UniformTypeIdentifiers

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
        Task {
            do {
                guard let videoData = try await item.loadTransferable(type: Data.self) else {
                    throw URLError(.badURL)
                }
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                try videoData.write(to: tempURL)
                
                await MainActor.run {
                    self.selectedVideoURL = tempURL
                    self.player = AVPlayer(url: tempURL)
                    self.player?.play()
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load video: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func uploadVideo() async {
        guard let videoURL = selectedVideoURL else {
            errorMessage = "No video selected."
            return
        }
        
        guard !caption.isEmpty else {
            errorMessage = "Please add a caption."
            return
        }
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadProgress = 0.0
        
        do {
            let downloadURL = try await VideoUploader.uploadVideo(fileURL: videoURL)
            await MainActor.run {
                successMessage = "Video uploaded successfully!"
                isUploading = false
                uploadProgress = 1.0
                // Reset the view after a successful upload
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.selectedItem = nil
                    self.selectedVideoURL = nil
                    self.player = nil
                    self.caption = ""
                    self.successMessage = nil
                    self.uploadProgress = 0.0
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                isUploading = false
            }
        }
    }
}

#Preview {
    VideoUploadView()
} 