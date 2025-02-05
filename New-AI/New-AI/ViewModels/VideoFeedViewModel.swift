import Foundation
import FirebaseFirestore
import os.log
import Combine

@MainActor
class VideoFeedViewModel: ObservableObject {
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
    
    // MARK: - Initialization
    init() {
        logger.notice("Initializing VideoFeedViewModel")
        Task {
            await fetchInitialVideos()
        }
    }
    
    deinit {
        Task { @MainActor in
            await self.removeListener()
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
            logger.debug("Query created with status filter: processed")
            
            let snapshot = try await query.getDocuments()
            logger.debug("Query executed. Documents count: \(snapshot.documents.count)")
            
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
        guard !self.isLoading,
              !self.isLoadingMore,
              self.hasMoreVideos,
              let lastDoc = self.lastDocument else {
            logger.debug("Skipping loadMore - conditions not met: loading=\(self.isLoading), loadingMore=\(self.isLoadingMore), hasMore=\(self.hasMoreVideos), lastDoc=\(self.lastDocument != nil)")
            return
        }
        
        self.isLoadingMore = true
        logger.notice("Loading more videos after document: \(lastDoc.documentID)")
        
        do {
            let query = createBaseQuery()
                .start(afterDocument: lastDoc)
                .limit(to: pageSize)
            
            let snapshot = try await query.getDocuments()
            self.lastDocument = snapshot.documents.last
            
            let newVideos = try snapshot.documents.compactMap { document -> Video in
                let video = try document.data(as: Video.self)
                logger.debug("Fetched additional video: \(video.id), engagement score: \(video.engagementScore)")
                return video
            }
            
            self.videos.append(contentsOf: newVideos)
            self.hasMoreVideos = !snapshot.documents.isEmpty
            
            logger.notice("Successfully loaded \(newVideos.count) more videos")
        } catch {
            logger.error("Error loading more videos: \(error.localizedDescription)")
            self.error = error
        }
        
        self.isLoadingMore = false
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
        var query: Query = db.collection("videos")
            .order(by: "engagementScore", descending: true)
        
        if selectedTab == 0 { // Following tab
            // TODO: Implement following logic when user following feature is ready
            logger.debug("Following tab query - feature pending implementation")
        }
        
        return query.whereField("status", in: ["processing", "processed"])
    }
    
    private func setupRealtimeListener() {
        logger.notice("Setting up realtime listener for video updates")
        removeListener() // Remove any existing listener
        
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
            
            do {
                let updatedVideos = try snapshot.documents.compactMap { document -> Video in
                    let video = try document.data(as: Video.self)
                    self.logger.debug("Realtime update for video: \(video.id), engagement score: \(video.engagementScore)")
                    return video
                }
                
                // Only update if there are actual changes
                if !updatedVideos.isEmpty && self.videos != updatedVideos {
                    self.logger.notice("Applying realtime updates - \(updatedVideos.count) videos")
                    self.videos = updatedVideos
                }
            } catch {
                self.logger.error("Error decoding realtime updates: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
    
    @MainActor
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