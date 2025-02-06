import Foundation
import FirebaseFirestore
import os.log
import Combine
import FirebaseAuth

@MainActor
final class VideoFeedViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedTab: Int = 1 // 0: Following, 1: For You
    @Published var currentVideoIndex: Int = 0
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoFeedViewModel")
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 5
    private var listenerRegistration: ListenerRegistration?
    private var isLoadingMore = false
    private var allVideosLoaded = false
    
    // MARK: - Initialization
    init() {
        self.logger.notice("Initializing VideoFeedViewModel")
        Task {
            await self.fetchInitialVideos()
        }
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.removeListener()
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches the initial batch of videos and sets up real-time listener
    func fetchInitialVideos() async {
        guard !self.isLoading else {
            self.logger.debug("Skipping fetchInitialVideos - already loading")
            return
        }
        
        self.logger.notice("Fetching initial videos batch with pageSize: \(self.pageSize)")
        self.isLoading = true
        self.error = nil
        
        do {
            let query = self.createBaseQuery()
                .limit(to: self.pageSize)
            
            let snapshot = try await query.getDocuments()
            self.logger.debug("Fetched \(snapshot.documents.count) initial videos")
            
            self.videos = snapshot.documents.compactMap { document -> Video? in
                do {
                    return try document.data(as: Video.self)
                } catch {
                    self.logger.error("Error decoding video document: \(error.localizedDescription)")
                    return nil
                }
            }
            
            self.lastDocument = snapshot.documents.last
            self.allVideosLoaded = snapshot.documents.count < self.pageSize
            
            self.logger.notice("Initial videos loaded. Total count: \(self.videos.count)")
            self.logger.debug("All videos loaded: \(self.allVideosLoaded)")
            
            // Setup real-time listener after successful initial fetch
            self.setupRealtimeListener()
            
        } catch {
            self.logger.error("Error fetching initial videos: \(error.localizedDescription)")
            self.error = error
        }
        
        self.isLoading = false
    }
    
    /// Fetches the next batch of videos for infinite scrolling
    func loadMoreVideos() async {
        guard !self.isLoading && !self.isLoadingMore && !self.allVideosLoaded && self.lastDocument != nil else {
            self.logger.debug("Skipping loadMoreVideos - isLoading: \(self.isLoading), isLoadingMore: \(self.isLoadingMore), allVideosLoaded: \(self.allVideosLoaded), lastDocument exists: \(self.lastDocument != nil)")
            return
        }
        
        self.logger.notice("Loading more videos...")
        self.isLoadingMore = true
        self.error = nil
        
        do {
            let query = self.createBaseQuery()
                .start(afterDocument: self.lastDocument!)
                .limit(to: self.pageSize)
            
            let snapshot = try await query.getDocuments()
            self.logger.debug("Fetched \(snapshot.documents.count) additional videos")
            
            let newVideos = snapshot.documents.compactMap { document -> Video? in
                do {
                    return try document.data(as: Video.self)
                } catch {
                    self.logger.error("Error decoding video document: \(error.localizedDescription)")
                    return nil
                }
            }
            
            self.videos.append(contentsOf: newVideos)
            self.lastDocument = snapshot.documents.last
            self.allVideosLoaded = snapshot.documents.count < self.pageSize
            
            self.logger.notice("Additional videos loaded. Total count: \(self.videos.count)")
            self.logger.debug("All videos loaded: \(self.allVideosLoaded)")
            
        } catch {
            self.logger.error("Error loading more videos: \(error.localizedDescription)")
            self.error = error
        }
        
        self.isLoadingMore = false
    }
    
    /// Refreshes the video feed
    func refreshFeed() async {
        self.logger.notice("Refreshing video feed")
        self.removeListener()
        self.lastDocument = nil
        self.allVideosLoaded = false
        self.error = nil
        await self.fetchInitialVideos()
    }
    
    /// Updates the selected tab (Following/For You) and refreshes content
    func updateSelectedTab(_ tab: Int) async {
        guard tab != self.selectedTab else { return }
        self.logger.notice("Switching to tab: \(tab)")
        self.selectedTab = tab
        await self.refreshFeed()
    }
    
    @MainActor
    func moveToNextVideo() {
        guard currentVideoIndex < videos.count - 1 else { return }
        currentVideoIndex += 1
        
        // Load more videos if we're near the end
        if currentVideoIndex >= videos.count - 2 {
            Task {
                await loadMoreVideos()
            }
        }
    }
    
    @MainActor
    func moveToPreviousVideo() {
        guard currentVideoIndex > 0 else { return }
        currentVideoIndex -= 1
    }
    
    // MARK: - Private Methods
    
    /// Creates the base Firestore query for fetching videos, ordered by engagementScore.
    private func createBaseQuery() -> Query {
        let query = self.db.collection("videos")
            .order(by: "likeCount", descending: true)
        
        if self.selectedTab == 0 {
            // Following tab: Implement user-specific feed logic here
            self.logger.debug("Following tab query - feature pending implementation")
            // TODO: Add following-specific query filters
        }
        
        self.logger.debug("Created base query ordered by likeCount")
        return query
    }
    
    private func setupRealtimeListener() {
        self.logger.notice("Setting up realtime listener for video updates")
        self.removeListener()
        
        let query = self.createBaseQuery().limit(to: self.pageSize)
        
        self.listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Realtime listener error: \(error.localizedDescription)")
                self.error = error
                return
            }
            
            guard let snapshot = snapshot else {
                self.logger.error("Nil snapshot in realtime update")
                return
            }
            
            let updatedVideos = snapshot.documents.compactMap { document -> Video? in
                do {
                    let video = try document.data(as: Video.self)
                    self.logger.debug("Realtime update for video: \(video.id), engagement score: \(video.engagementScore)")
                    return video
                } catch {
                    self.logger.error("Failed to decode video document \(document.documentID): \(error.localizedDescription)")
                    return nil
                }
            }
            
            if !updatedVideos.isEmpty && self.videos != updatedVideos {
                self.logger.notice("Applying realtime updates - \(updatedVideos.count) videos")
                self.videos = updatedVideos
            }
        }
    }
    
    private func removeListener() {
        self.listenerRegistration?.remove()
        self.listenerRegistration = nil
        self.logger.debug("Removed realtime listener")
    }
    
    /// Toggles like status for a video
    func toggleLike(for video: Video) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            self.logger.error("Failed to toggle like: User not logged in")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        self.logger.notice("Attempting to toggle like for video: \(video.id), current like count: \(video.likeCount)")
        
        let videoRef = db.collection("videos").document(video.id)
        let likeRef = videoRef.collection("likes").document(userID)
        let userLikedVideoRef = db.collection("users").document(userID)
            .collection("likedVideos").document(video.id)
        
        do {
            let likeDoc = try await likeRef.getDocument()
            self.logger.debug("Like document exists: \(likeDoc.exists), for video: \(video.id)")
            
            if likeDoc.exists {
                // Unlike the video
                self.logger.notice("Unliking video: \(video.id)")
                let _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                    // Remove the like document from video's likes collection
                    transaction.deleteDocument(likeRef)
                    
                    // Remove from user's likedVideos collection
                    transaction.deleteDocument(userLikedVideoRef)
                    
                    // Decrement the video's like count
                    transaction.updateData([
                        "likeCount": FieldValue.increment(Int64(-1))
                    ], forDocument: videoRef)
                    
                    return nil
                }
                
                // Get the updated video document to ensure we have the correct state
                let updatedDoc = try await videoRef.getDocument()
                if let updatedVideo = try? updatedDoc.data(as: Video.self) {
                    // Update local state with the verified Firestore state
                    if let index = videos.firstIndex(where: { $0.id == video.id }) {
                        self.logger.debug("Before unlike - Video at index \(index) has \(self.videos[index].likeCount) likes")
                        self.videos[index].likeCount = updatedVideo.likeCount
                        self.logger.debug("After unlike - Video now has \(self.videos[index].likeCount) likes")
                    }
                    self.logger.notice("Video unliked: \(video.id), new like count: \(updatedVideo.likeCount)")
                }
                
            } else {
                // Like the video
                self.logger.notice("Liking video: \(video.id)")
                let _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                    // Create the like document in video's likes collection
                    transaction.setData([
                        "userID": userID,
                        "likedAt": FieldValue.serverTimestamp()
                    ], forDocument: likeRef)
                    
                    // Add to user's likedVideos collection
                    transaction.setData([
                        "videoID": video.id,
                        "likedAt": FieldValue.serverTimestamp()
                    ], forDocument: userLikedVideoRef)
                    
                    // Increment the video's like count
                    transaction.updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ], forDocument: videoRef)
                    
                    return nil
                }
                
                // Get the updated video document to ensure we have the correct state
                let updatedDoc = try await videoRef.getDocument()
                if let updatedVideo = try? updatedDoc.data(as: Video.self) {
                    // Update local state with the verified Firestore state
                    if let index = videos.firstIndex(where: { $0.id == video.id }) {
                        self.logger.debug("Before like - Video at index \(index) has \(self.videos[index].likeCount) likes")
                        self.videos[index].likeCount = updatedVideo.likeCount
                        self.logger.debug("After like - Video now has \(self.videos[index].likeCount) likes")
                    }
                    self.logger.notice("Video liked: \(video.id), new like count: \(updatedVideo.likeCount)")
                }
            }
            
        } catch {
            self.logger.error("Error toggling like: \(error.localizedDescription)")
            throw error
        }
    }
} 