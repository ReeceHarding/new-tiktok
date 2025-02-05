import Foundation
import FirebaseFirestore
import os.log
import Combine

@MainActor
final class VideoFeedViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedTab: Int = 1 // 0: Following, 1: For You
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoFeedViewModel")
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 5
    private var listenerRegistration: ListenerRegistration?
    private var isLoadingMore = false
    private var hasMoreVideos = true
    private var allVideosLoaded = false
    
    // MARK: - Initialization
    init() {
        logger.notice("Initializing VideoFeedViewModel")
        Task {
            await fetchInitialVideos()
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
        guard !isLoading else { return }
        isLoading = true
        logger.notice("Fetching initial videos batch, pageSize: \(self.pageSize)")
        
        do {
            let query = createBaseQuery()
            logger.debug("Query created")
            
            let snapshot = try await query.getDocuments()
            logger.debug("Query executed. Documents count: \(snapshot.documents.count)")
            
            // Log raw document data for debugging
            for doc in snapshot.documents {
                logger.debug("Raw document data: \(doc.data())")
            }
            
            self.lastDocument = snapshot.documents.last
            let fetchedVideos = try snapshot.documents.compactMap { document -> Video in
                logger.debug("Processing document: \(document.documentID)")
                let video = try document.data(as: Video.self)
                logger.debug("Successfully decoded video: \(video.id), status: \(video.status), engagement score: \(video.engagementScore)")
                return video
            }
            
            self.videos = fetchedVideos
            self.hasMoreVideos = !snapshot.documents.isEmpty
            self.setupRealtimeListener()
            
            logger.notice("Successfully fetched \(fetchedVideos.count) initial videos")
        } catch {
            logger.error("Error fetching initial videos: \(error.localizedDescription), detailed error: \(String(describing: error))")
            self.error = error
        }
        
        self.isLoading = false
    }
    
    /// Fetches the next batch of videos for infinite scrolling
    func loadMoreVideos() async {
        guard !isLoading, !allVideosLoaded else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var query = db.collection("videos")
                .order(by: "uploadDate", descending: true)
                .limit(to: pageSize)
            
            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument)
            }
            
            let snapshot = try await query.getDocuments()
            
            guard !snapshot.documents.isEmpty else {
                allVideosLoaded = true
                return
            }
            
            let newVideos = try snapshot.documents.map { try $0.data(as: Video.self) }
            videos.append(contentsOf: newVideos)
            lastDocument = snapshot.documents.last
            
        } catch {
            logger.error("Error loading videos: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Refreshes the video feed
    func refreshFeed() async {
        logger.notice("Refreshing video feed")
        removeListener()
        self.lastDocument = nil
        self.hasMoreVideos = true
        await fetchInitialVideos()
    }
    
    /// Updates the selected tab (Following/For You) and refreshes content
    func updateSelectedTab(_ tab: Int) async {
        guard tab != selectedTab else { return }
        logger.notice("Switching to tab: \(tab)")
        self.selectedTab = tab
        await refreshFeed()
    }
    
    // MARK: - Private Methods
    
    private func createBaseQuery() -> Query {
        let query: Query = db.collection("videos")
            .order(by: "engagementScore", descending: true)
            // Removed status filter to show all videos
        
        if selectedTab == 0 {
            logger.debug("Following tab query - feature pending implementation")
        }
        
        logger.debug("Created base query ordered by engagementScore")
        return query
    }
    
    private func setupRealtimeListener() {
        logger.notice("Setting up realtime listener for video updates")
        removeListener()
        
        let query = createBaseQuery().limit(to: pageSize)
        
        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
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
                    self.logger.error("Failed to decode video document \(document.documentID): \(error)")
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
        listenerRegistration?.remove()
        listenerRegistration = nil
        logger.debug("Removed realtime listener")
    }
    
    private func loadMore() async {
        guard !self.isLoading && !self.isLoadingMore && self.hasMoreVideos && self.lastDocument != nil else {
            logger.debug("Skipping load more: isLoading=\(self.isLoading), isLoadingMore=\(self.isLoadingMore), hasMoreVideos=\(self.hasMoreVideos), lastDocument=\(String(describing: self.lastDocument))")
            return
        }

        do {
            self.isLoadingMore = true
            let query = createQuery().start(afterDocument: self.lastDocument!)
            let snapshot = try await query.getDocuments()
            
            if let lastDoc = snapshot.documents.last {
                self.lastDocument = lastDoc
                self.hasMoreVideos = snapshot.documents.count >= pageSize
            } else {
                self.hasMoreVideos = false
            }
            
            let newVideos = try snapshot.documents.map { try $0.data(as: Video.self) }
            await MainActor.run {
                self.videos.append(contentsOf: newVideos)
            }
        } catch {
            logger.error("Error loading more videos: \(error.localizedDescription)")
            self.error = error
        }
        
        self.isLoadingMore = false
    }
    
    private func createQuery() -> Query {
        let query: Query = db.collection("videos")
            .order(by: "engagementScore", descending: true)
            .limit(to: pageSize)
        return query
    }
} 