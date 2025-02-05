import SwiftUI
import FirebaseAuth

struct CommentsView: View {
    let video: Video
    @StateObject private var viewModel = CommentsViewModel()
    @State private var newComment = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showSignInAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showComments = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("\(video.comments) comments")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    
                    // Comments List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if let error = viewModel.error {
                                Text(error)
                                    .foregroundColor(.red)
                            } else {
                                ForEach(viewModel.comments) { comment in
                                    CommentRow(comment: comment, onLike: {
                                        Task {
                                            try? await viewModel.likeComment(comment)
                                        }
                                    })
                                    .opacity(showComments ? 1 : 0)
                                    .offset(y: showComments ? 0 : 20)
                                    .animation(
                                        .spring(response: 0.3, dampingFraction: 0.7)
                                        .delay(Double(viewModel.comments.firstIndex(where: { $0.id == comment.id }) ?? 0) * 0.05),
                                        value: showComments
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                    }
                    .background(Color.black)
                    
                    // Comment Input
                    VStack {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        HStack(spacing: 12) {
                            // User Avatar
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                            
                            // Text Input
                            HStack {
                                TextField("Add comment...", text: $newComment)
                                    .font(.system(size: 14))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(20)
                                    .foregroundColor(.white)
                                
                                if !newComment.isEmpty {
                                    Button(action: {
                                        Task {
                                            if Auth.auth().currentUser != nil {
                                                do {
                                                    try await viewModel.addComment(videoID: video.id, text: newComment)
                                                    newComment = ""
                                                } catch {
                                                    print("Error adding comment: \(error)")
                                                }
                                            } else {
                                                showSignInAlert = true
                                            }
                                        }
                                    }) {
                                        Text("Post")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .background(Color.black.opacity(0.8))
                }
                .background(Color.black)
                .cornerRadius(15)
                .padding(.bottom, keyboardHeight)
                .ignoresSafeArea(.keyboard)
            }
            .alert("Sign In Required", isPresented: $showSignInAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please sign in to add comments")
            }
            .onAppear {
                Task {
                    await viewModel.fetchComments(for: video.id)
                    withAnimation {
                        showComments = true
                    }
                }
            }
            .onDisappear {
                showComments = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
} 