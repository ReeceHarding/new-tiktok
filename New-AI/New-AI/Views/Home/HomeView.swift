import SwiftUI
import AVKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import ObjectiveC
import os.log

// MARK: - Tab Bar Item View
struct TabBarItemView: View {
    let imageName: String
    let title: String
    let isSystemImage: Bool
    
    var body: some View {
        VStack(spacing: 3) {
            if isSystemImage {
                Image(systemName: imageName)
                    .environment(\.symbolVariants, title == "Create" ? .none : .fill)
                    .font(.system(size: title == "Create" ? 24 : 20))
            } else {
                Image(imageName)
            }
            Text(title)
                .font(.system(size: 11))
        }
    }
}

// MARK: - Feed Header View
struct FeedHeaderView: View {
    @Binding var selectedTab: Int
    @Namespace var animation
    @ObservedObject var viewModel: VideoFeedViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            Text("Following")
                .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                .font(.system(size: 18, weight: selectedTab == 0 ? .semibold : .regular))
                .overlay(alignment: .bottom) {
                    if selectedTab == 0 {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.white)
                            .matchedGeometryEffect(id: "TAB", in: animation)
                            .padding(.horizontal, 4)
                    }
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 0
                        Task {
                            await viewModel.updateSelectedTab(0)
                        }
                    }
                }
            
            Text("For You")
                .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                .font(.system(size: 18, weight: selectedTab == 1 ? .semibold : .regular))
                .overlay(alignment: .bottom) {
                    if selectedTab == 1 {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.white)
                            .matchedGeometryEffect(id: "TAB", in: animation)
                            .padding(.horizontal, 4)
                    }
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 1
                        Task {
                            await viewModel.updateSelectedTab(1)
                        }
                    }
                }
        }
        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47)
        .padding(.bottom, 8)
    }
}

// MARK: - Video Feed View (Dynamic, Infinite Scrolling)
struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var currentIndex = 0
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoFeedView")
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView("Loading videos...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .onAppear {
                        logger.debug("Initial loading started in VideoFeedView")
                    }
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        Task {
                            logger.debug("Retry button pressed in VideoFeedView")
                            await viewModel.refreshFeed()
                        }
                    }
                }
                .foregroundColor(.white)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                VideoPlayerFullScreenView(video: video, isActive: index == currentIndex)
                                    .id(index)
                                    .frame(height: UIScreen.main.bounds.height)
                                    .onAppear {
                                        if index == currentIndex {
                                            logger.debug("Video at index \(index) appeared in ScrollView")
                                        }
                                        // Preload next video
                                        if index == currentIndex + 1 {
                                            logger.debug("Preloading next video at index \(index)")
                                        }
                                    }
                            }
                        }
                    }
                    .scrollDisabled(true)  // Disable default scroll behavior
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let height = UIScreen.main.bounds.height
                                let velocity = value.predictedEndLocation.y - value.location.y
                                
                                withAnimation {
                                    if velocity < 0 && currentIndex < viewModel.videos.count - 1 {
                                        currentIndex += 1
                                        proxy.scrollTo(currentIndex, anchor: .center)
                                    } else if velocity > 0 && currentIndex > 0 {
                                        currentIndex -= 1
                                        proxy.scrollTo(currentIndex, anchor: .center)
                                    }
                                }
                            }
                    )
                }
                .onChange(of: currentIndex) { oldIndex, newIndex in
                    logger.debug("Current video index changed to \(newIndex)")
                    if newIndex >= max(0, viewModel.videos.count - 2) {
                        Task {
                            logger.notice("Loading more videos")
                            await viewModel.loadMoreVideos()
                        }
                    }
                }
            }
        }
        .refreshable {
            logger.notice("User triggered manual refresh")
            await viewModel.refreshFeed()
        }
    }
}

// MARK: - Main Home View
struct HomeView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var currentIndex = 0
    
    var body: some View {
        TabView {
            // Main Feed View (Home Tab)
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    FeedHeaderView(selectedTab: $viewModel.selectedTab, viewModel: viewModel)
                    VideoFeedView()
                }
            }
            .tabItem {
                TabBarItemView(imageName: "house", title: "Home", isSystemImage: true)
            }
            .tag(0)
            
            // Discover Tab
            Color.black.ignoresSafeArea()
                .tabItem {
                    TabBarItemView(imageName: "magnifyingglass", title: "Discover", isSystemImage: true)
                }
                .tag(1)
            
            // Create Tab
            VideoUploadView()
                .tabItem {
                    TabBarItemView(imageName: "plus.app.fill", title: "Create", isSystemImage: true)
                }
                .tag(2)
            
            // Inbox Tab
            Color.black.ignoresSafeArea()
                .tabItem {
                    TabBarItemView(imageName: "message", title: "Inbox", isSystemImage: true)
                }
                .tag(3)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    TabBarItemView(imageName: "person", title: "Me", isSystemImage: true)
                }
                .tag(4)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

struct VideoPlayerFullScreenView: View {
    let video: Video
    let isActive: Bool
    
    @State private var isLiked = false
    @State private var showingComments = false
    @State private var isMusicDiscRotating = true
    @State private var isProfileHovered = false
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var showControls = false
    @State private var likeScale = 1.0
    @State private var showHeartAnimation = false
    @State private var heartPosition: CGPoint = .zero
    @State private var progress: Double = 0
    @State private var videoDuration: Double = 0
    @State private var scale: CGFloat = 1.0
    
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoPlayerFullScreenView")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Layer
                if let player = player {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(Color.black.opacity(showControls ? 0.4 : 0))
                        .onTapGesture {
                            isPlaying.toggle()
                            if isPlaying {
                                player.play()
                            } else {
                                player.pause()
                            }
                        }
                        .onTapGesture(count: 2) { location in
                            heartPosition = location
                            showHeartAnimation = true
                            isLiked = true
                            likeScale = 1.5
                            
                            // Reset animations
                            withAnimation(.spring(response: 0.3)) {
                                likeScale = 1.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showHeartAnimation = false
                            }
                        }
                } else {
                    Color.black
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                
                // Video Controls Overlay
                if showControls {
                    VStack {
                        Spacer()
                        
                        // Progress Bar
                        VStack(spacing: 8) {
                            Slider(value: $progress, in: 0...1) { editing in
                                if !editing {
                                    let time = progress * videoDuration
                                    player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
                                }
                            }
                            .accentColor(.white)
                            
                            // Time Labels
                            HStack {
                                Text(formatTime(progress * videoDuration))
                                Spacer()
                                Text(formatTime(videoDuration))
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        
                        // Playback Controls
                        HStack(spacing: 40) {
                            Button(action: {
                                if let currentTime = player?.currentTime().seconds {
                                    player?.seek(to: CMTime(seconds: max(0, currentTime - 10), preferredTimescale: 600))
                                }
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.title)
                            }
                            
                            Button(action: {
                                isPlaying.toggle()
                                if isPlaying {
                                    player?.play()
                                } else {
                                    player?.pause()
                                }
                            }) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 56))
                            }
                            
                            Button(action: {
                                if let currentTime = player?.currentTime().seconds {
                                    player?.seek(to: CMTime(seconds: min(videoDuration, currentTime + 10), preferredTimescale: 600))
                                }
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.title)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.bottom, 30)
                    }
                }
                
                // Interaction Overlay
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 0) {
                        // Left side - Video Info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("@\(video.uploaderID)")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                            }
                            
                            Text(video.title)
                                .font(.system(size: 14))
                                .lineLimit(2)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                Text(video.description)
                                    .font(.system(size: 14))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.bottom, 12)
                        
                        Spacer()
                        
                        // Right side - Action Buttons
                        VStack(spacing: 16) {
                            // Profile Button with Avatar
                            Button(action: {}) {
                                ZStack(alignment: .bottom) {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 44))
                                                .foregroundColor(.white)
                                        )
                                    
                                    // Add button
                                    Circle()
                                        .fill(Color.pink)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(y: 10)
                                }
                            }
                            
                            // Like Button
                            VStack(spacing: 2) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isLiked.toggle()
                                        if isLiked {
                                            scale = 1.3
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation {
                                                    scale = 1.0
                                                }
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 30))
                                        .foregroundColor(isLiked ? .white : .white)
                                        .scaleEffect(scale)
                                }
                                Text("\(video.likeCount)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            
                            // Comments Button
                            VStack(spacing: 2) {
                                Button(action: {
                                    showingComments.toggle()
                                }) {
                                    Image(systemName: "ellipsis.bubble")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                                Text("\(video.commentCount)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            
                            // Share Button
                            VStack(spacing: 2) {
                                Button(action: {}) {
                                    Image(systemName: "arrowshape.turn.up.right")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                                Text("Share")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            
                            // Music Disc
                            Button(action: {}) {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .background(Circle().fill(Color.black))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    )
                                    .rotationEffect(.degrees(isMusicDiscRotating ? 360 : 0))
                                    .animation(
                                        Animation.linear(duration: 3)
                                            .repeatForever(autoreverses: false),
                                        value: isMusicDiscRotating
                                    )
                            }
                        }
                        .padding(.trailing, 8)
                        .padding(.bottom, 20)
                    }
                }
                .opacity(showControls ? 0 : 1)
                
                // Double Tap Heart Animation
                if showHeartAnimation {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .position(heartPosition)
                        .scaleEffect(showHeartAnimation ? 1.0 : 0.0)
                        .opacity(showHeartAnimation ? 0.0 : 1.0)
                        .animation(.easeOut(duration: 0.5), value: showHeartAnimation)
                }
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                setupVideoIfNeeded()
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
            }
        }
        .onAppear {
            if isActive {
                setupVideoIfNeeded()
            }
        }
        .onDisappear {
            cleanupVideo()
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(viewModel: CommentsViewModel(videoID: video.id), videoID: video.id)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func setupVideoIfNeeded() {
        guard player == nil else { return }
        
        guard let url = URL(string: video.videoURL) else {
            logger.error("Invalid video URL for video ID: \(video.id)")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Setup video duration
        Task {
            do {
                let duration = try await playerItem.asset.load(.duration)
                if duration.isValid && !duration.isIndefinite {
                    await MainActor.run {
                        self.videoDuration = duration.seconds
                    }
                }
            } catch {
                logger.error("Failed to load video duration: \(error.localizedDescription)")
            }
        }
        
        // Add progress observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard self.videoDuration > 0 else { return }
            self.progress = time.seconds / self.videoDuration
        }
        
        // Add loop observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main) { _ in
                self.player?.seek(to: .zero)
                self.player?.play()
            }
        
        if isActive {
            player?.play()
            isPlaying = true
        }
    }
    
    private func cleanupVideo() {
        player?.pause()
        player = nil
        progress = 0
        videoDuration = 0
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - UI Components
struct ProfileButton: View {
    @Binding var isHovered: Bool
    
    var body: some View {
        Button(action: {}) {
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isHovered)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct LikeButton: View {
    @Binding var isLiked: Bool
    let likeCount: Int
    @Binding var scale: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                    if isLiked {
                        scale = 1.3
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scale = 1.0
                            }
                        }
                    }
                }
            }) {
                VStack {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 28))
                        .foregroundColor(isLiked ? .red : .white)
                        .scaleEffect(scale)
                    Text("\(likeCount)")
                        .font(.system(size: 12))
                }
            }
        }
    }
}

struct CommentButton: View {
    @Binding var showingComments: Bool
    let commentCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showingComments.toggle()
                }
            }) {
                VStack {
                    Image(systemName: "bubble.right.fill")
                        .font(.system(size: 26))
                        .scaleEffect(showingComments ? 1.2 : 1.0)
                    Text("\(commentCount)")
                        .font(.system(size: 12))
                }
            }
        }
    }
}

struct ShareButton: View {
    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    // Share action
                }
            }) {
                VStack {
                    Image(systemName: "arrowshape.turn.up.forward.fill")
                        .font(.system(size: 26))
                    Text("Share")
                        .font(.system(size: 12))
                }
            }
        }
    }
}

struct MusicDisc: View {
    @Binding var isRotating: Bool
    
    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.6))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.white)
            )
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                Animation.linear(duration: 3)
                    .repeatForever(autoreverses: false),
                value: isRotating
            )
    }
}

#Preview {
    HomeView()
} 