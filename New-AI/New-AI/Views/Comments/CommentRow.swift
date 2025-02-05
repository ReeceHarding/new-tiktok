import SwiftUI

struct CommentRow: View {
    let comment: Comment
    let onLike: () -> Void
    @State private var animateLike = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.username)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(timeAgo(from: comment.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Text(comment.text)
                .font(.system(size: 14))
                .lineLimit(3)
            
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        animateLike = true
                        onLike()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(comment.isLiked ? .red : .gray)
                            .scaleEffect(animateLike ? 1.2 : 1.0)
                        Text("\(comment.likes)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .onChange(of: animateLike) { _ in
            if animateLike {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateLike = false
                }
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 