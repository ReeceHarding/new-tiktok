import Foundation
import FirebaseFirestore
import os.log

@MainActor
class UserViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.eus.teacheditai3.TikTok", category: "UserViewModel")
    
    func fetchUserDisplayName(for userID: String) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let userDoc = try await db.collection("users").document(userID).getDocument()
            if let displayName = userDoc.data()?["displayName"] as? String {
                self.displayName = displayName
            } else {
                self.displayName = "Unknown User"
            }
        } catch {
            logger.error("Error fetching user display name: \(error.localizedDescription)")
            self.error = error
            self.displayName = "Unknown User"
        }
        
        isLoading = false
    }
} 