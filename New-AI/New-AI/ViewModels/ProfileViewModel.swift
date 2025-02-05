import Foundation
import FirebaseAuth
import FirebaseFirestore

struct UserProfile {
    let username: String
    let email: String
    let bio: String?
    let role: String
    let registrationDate: Date
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    func fetchUserProfile() async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            showError = true
            return
        }
        
        do {
            let docRef = db.collection("users").document(currentUser.uid)
            let document = try await docRef.getDocument()
            
            if let data = document.data() {
                let username = data["username"] as? String ?? "Unknown"
                let email = currentUser.email ?? "No email"
                let bio = data["bio"] as? String
                let role = data["role"] as? String ?? "user"
                let registrationDate = (data["registrationDate"] as? Timestamp)?.dateValue() ?? Date()
                
                userProfile = UserProfile(
                    username: username,
                    email: email,
                    bio: bio,
                    role: role,
                    registrationDate: registrationDate
                )
            }
        } catch {
            print("❌ Error fetching user profile: \(error)")
            errorMessage = "Failed to load profile"
            showError = true
        }
    }
    
    func signOut() async {
        do {
            try Auth.auth().signOut()
        } catch {
            print("❌ Error signing out: \(error)")
            errorMessage = "Failed to sign out"
            showError = true
        }
    }
} 