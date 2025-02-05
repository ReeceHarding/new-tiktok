import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommentsView: View {
    @StateObject var viewModel: CommentsViewModel
    @Environment(\.dismiss) var dismiss
    let videoID: String
    @State private var newCommentText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            commentsList
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
    }
    
    private var commentsList: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment, videoID: videoID, onLike: {
                                Task {
                                    try? await viewModel.toggleLike(for: comment)
                                }
                            })
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            commentInputField
        }
    }
    
    private var commentInputField: some View {
        HStack {
            TextField("Add a comment...", text: $newCommentText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(viewModel.isSubmitting)
            
            Button(action: {
                Task {
                    await submitComment()
                }
            }) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Post")
                        .foregroundColor(newCommentText.isEmpty ? .gray : .blue)
                }
            }
            .disabled(newCommentText.isEmpty || viewModel.isSubmitting)
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submitComment() async {
        do {
            try await viewModel.addComment(text: newCommentText)
            newCommentText = ""
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
} 