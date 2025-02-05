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
        VStack {
            if isSystemImage {
                Image(systemName: imageName)
                    .environment(\.symbolVariants, title == "Create" ? .none : .fill)
            } else {
                Image(imageName)
            }
            Text(title)
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
                .foregroundColor(selectedTab == 0 ? .white : .gray)
                .fontWeight(selectedTab == 0 ? .semibold : .regular)
                .overlay(alignment: .bottom) {
                    if selectedTab == 0 {
                        Rectangle()
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "TAB", in: animation)
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
                .foregroundColor(selectedTab == 1 ? .white : .gray)
                .fontWeight(selectedTab == 1 ? .semibold : .regular)
                .overlay(alignment: .bottom) {
                    if selectedTab == 1 {
                        Rectangle()
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "TAB", in: animation)
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
        .font(.system(size: 16))
        .padding(.top, 50)
        .padding(.bottom, 20)
    }
}

// MARK: - Video Feed View
struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var currentIndex = 0
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "VideoFeedView")
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView("Loading videos...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                            await viewModel.refreshFeed()
                        }
                    }
                }
                .foregroundColor(.white)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                        VideoPlayerFullScreenView(video: video)
                            .rotationEffect(.degrees(0))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(index)
                            .onChange(of: currentIndex) { newIndex in
                                if newIndex == viewModel.videos.count - 2 {
                                    logger.debug("Approaching end of feed at index \(newIndex), loading more videos")
                                    Task {
                                        await viewModel.loadMoreVideos()
                                    }
                                }
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea(edges: [.top])
            }
        }
        .refreshable {
            logger.notice("Manual refresh triggered")
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
            
            // Create Tab - Updated to show VideoUploadView
            VideoUploadView()
                .tabItem {
                    TabBarItemView(imageName: "plus", title: "Create", isSystemImage: true)
                }
                .tag(2)
            
            // Inbox Tab
            Color.black.ignoresSafeArea()
                .tabItem {
                    TabBarItemView(imageName: "message", title: "Inbox", isSystemImage: true)
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    TabBarItemView(imageName: "person", title: "Profile", isSystemImage: true)
                }
                .tag(4)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

struct VideoPlayerFullScreenView: View {
    let video: Video
    @State private var isLiked = false
    @State private var showingComments = false
    @State private var isMusicDiscRotating = true
    @State private var isProfileHovered = false
    @State private var dragAmount = CGSize.zero
    @State private var player: AVPlayer?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Video Content
                if let player = player {
                    VideoPlayer(player: player)
                        .onDisappear {
                            player.pause()
                        }
                } else {
                    Color.black
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                
                VStack {
                    // Right side buttons
                    VStack(spacing: 20) {
                        // Profile Picture with hover animation
                        Button(action: {}) {
                            Circle()
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(.white)
                                )
                                .scaleEffect(isProfileHovered ? 1.1 : 1.0)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: isProfileHovered ? 2 : 0)
                                )
                                .onHover { hovering in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isProfileHovered = hovering
                                    }
                                }
                        }
                        
                        // Like Button with heart animation
                        VStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isLiked.toggle()
                                }
                            }) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 28))
                                    .foregroundColor(isLiked ? .red : .white)
                                    .scaleEffect(isLiked ? 1.2 : 1.0)
                            }
                            Text("4445")
                                .font(.system(size: 12))
                        }
                        
                        // Comment Button with bounce
                        VStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    showingComments.toggle()
                                }
                            }) {
                                Image(systemName: "ellipsis.message.fill")
                                    .font(.system(size: 28))
                                    .scaleEffect(showingComments ? 1.2 : 1.0)
                            }
                            Text("\(video.comments)")
                                .font(.system(size: 12))
                        }
                        
                        // Share Button with rotation
                        VStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    // Share animation
                                }
                            }) {
                                Image(systemName: "arrowshape.turn.up.forward.fill")
                                    .font(.system(size: 28))
                                    .rotationEffect(.degrees(dragAmount == .zero ? 0 : 30))
                            }
                            Text("Share")
                                .font(.system(size: 12))
                        }
                        
                        // Rotating Music Disc
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                            )
                            .rotationEffect(.degrees(isMusicDiscRotating ? 360 : 0))
                            .animation(
                                Animation.linear(duration: 3)
                                    .repeatForever(autoreverses: false),
                                value: isMusicDiscRotating
                            )
                    }
                    .foregroundColor(.white)
                    .padding(.trailing, 10)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    Spacer()
                    
                    // Bottom text overlay with slide-up animation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@username")
                            .font(.system(size: 16, weight: .semibold))
                            .transition(.move(edge: .bottom))
                        
                        Text("#ai #productivity")
                            .font(.system(size: 14, weight: .regular))
                            .transition(.move(edge: .bottom))
                        
                        HStack {
                            Image(systemName: "music.note")
                                .font(.system(size: 14))
                            Text("Original Sound")
                                .font(.system(size: 14))
                        }
                        .transition(.move(edge: .bottom))
                    }
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            isMusicDiscRotating = true
            if player == nil {
                setupVideo()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(video: video)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func setupVideo() {
        guard let url = URL(string: video.videoURL) else { return }
        
        func attemptLoad(retries: Int = 3) {
            guard retries > 0 else {
                print("❌ Failed to load video after multiple attempts")
                return
            }
            
            let player = AVPlayer(url: url)
            player.automaticallyWaitsToMinimizeStalling = true
            
            // Add observer for item status
            let observation = player.currentItem?.observe(\.status) { item, _ in
                switch item.status {
                case .failed:
                    print("🔄 Retry attempt \(4 - retries): \(item.error?.localizedDescription ?? "Unknown error")")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        attemptLoad(retries: retries - 1)
                    }
                case .readyToPlay:
                    DispatchQueue.main.async {
                        self.player = player
                        player.play()
                    }
                default:
                    break
                }
            }
            
            // Store observation to prevent deallocation
            objc_setAssociatedObject(player, "statusObservation", observation, .OBJC_ASSOCIATION_RETAIN)
        }
        
        attemptLoad()
    }
    
    private func handleDoubleTap(at location: CGPoint, in geometry: GeometryProxy) {
        if !isLiked {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isLiked = true
            }
        }
    }
}

#Preview {
    HomeView()
} 