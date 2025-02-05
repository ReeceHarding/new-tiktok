import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommentRow: View {
    let comment: Comment
    let videoID: String
    let onLike: () -> Void
    @StateObject private var userViewModel = UserViewModel()
    @State private var animateLike = false
    @State private var scale = 1.0
    @State private var isLiked = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(userViewModel.displayName)
                    .font(.system(size: 14, weight: .semibold))
                Text(comment.text)
                    .font(.system(size: 14))
                
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            animateLike.toggle()
                            onLike()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(isLiked ? .red : .gray)
                                .scaleEffect(scale)
                            Text("\(comment.likeCount)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(comment.timestamp.timeAgoDisplay())
                        if comment.edited {
                            Text("(edited)")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            Task {
                await userViewModel.fetchUserDisplayName(for: comment.userID)
                await checkIfLiked()
            }
        }
        .onChange(of: animateLike) { oldValue, newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.3
                } completion: {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                        scale = 1.0
                        animateLike = false
                    }
                }
            }
        }
    }
    
    private func checkIfLiked() async {
        guard let commentID = comment.id,
              let userID = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            let likeDoc = try await db.collection("videos")
                .document(videoID)
                .collection("comments")
                .document(commentID)
                .collection("likes")
                .document(userID)
                .getDocument()
            
            isLiked = likeDoc.exists
        } catch {
            print("Error checking like status: \(error.localizedDescription)")
        }
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1y" : "\(year)y"
        }
        if let month = components.month, month > 0 {
            return month == 1 ? "1mo" : "\(month)mo"
        }
        if let day = components.day, day > 0 {
            return day == 1 ? "1d" : "\(day)d"
        }
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1h" : "\(hour)h"
        }
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1m" : "\(minute)m"
        }
        return "now"
    }
} 