import SwiftUI
import AVKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
    @Binding var currentIndex: Int
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<5) { index in
                VideoPlayerFullScreenView(video: Video(mockWithComments: 579))
                    .rotationEffect(.degrees(0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}

// MARK: - Main Home View
struct HomeView: View {
    @State private var selectedTab = 1 // Default to "For You"
    @State private var currentIndex = 0
    
    var body: some View {
        TabView {
            // Main Feed View (Home Tab)
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    FeedHeaderView(selectedTab: $selectedTab)
                    VideoFeedView(currentIndex: $currentIndex)
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
            
            Color.black.ignoresSafeArea()
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Video Content
                Color.black
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.5))
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { dragAmount = $0.translation }
                            .onEnded { value in
                                withAnimation(.spring()) {
                                    if abs(value.translation.height) > 100 {
                                        // Handle swipe
                                    }
                                    dragAmount = .zero
                                }
                            }
                    )
                    .offset(y: dragAmount.height)
                    .onTapGesture(count: 2) { location in
                        handleDoubleTap(at: location, in: geometry)
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
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(video: video)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
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