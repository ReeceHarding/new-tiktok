import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    private let db = Firestore.firestore()
    
    init() {
        print("🔍 DEBUG: Checking initial auth state...")
        if let currentUser = Auth.auth().currentUser {
            print("👤 DEBUG: User is already signed in")
            isAuthenticated = true
        }
        
        // Setup auth state listener
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                print("🔄 AUTH STATE CHANGED: User is \(user != nil ? "signed in" : "signed out")")
            }
        }
    }
    
    func signIn(withEmail email: String, password: String) async {
        print("🔑 DEBUG: Attempting sign in for email: \(email)")
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            errorMessage = nil
            print("✅ SUCCESS: User signed in - ID: \(result.user.uid)")
            print("📧 Email verified: \(result.user.isEmailVerified)")
            print("📱 Provider ID: \(result.user.providerID)")
        } catch {
            print("❌ AUTH ERROR: \(error)")
            handleAuthError(error)
        }
    }
    
    func createUser(withEmail email: String, password: String, username: String) async {
        print("""
            📝 DEBUG: Starting user creation process...
            - Email: \(email)
            - Username: \(username)
            - Password length: \(password.count)
            """)
        
        // Input validation
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            print("⚠️ VALIDATION: Empty fields detected")
            errorMessage = "Please fill in all fields"
            return
        }
        
        guard password.count >= 6 else {
            print("⚠️ VALIDATION: Password too short")
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        do {
            // First create the auth user
            print("🔐 DEBUG: Creating Firebase Auth user...")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("""
                ✅ SUCCESS: Firebase Auth user created
                - UID: \(result.user.uid)
                - Email: \(result.user.email ?? "no email")
                - Provider: \(result.user.providerID)
                """)
            
            // Then try to store in Firestore
            do {
                let userData: [String: Any] = [
                    "username": username,
                    "email": email,
                    "createdAt": Timestamp(date: Date())
                ]
                
                print("""
                    💾 DEBUG: Attempting to store user data in Firestore...
                    - Collection: users
                    - Document ID: \(result.user.uid)
                    - Data: \(userData)
                    """)
                
                // Check if document exists
                let docRef = db.collection("users").document(result.user.uid)
                let docSnapshot = try await docRef.getDocument()
                
                if docSnapshot.exists {
                    print("⚠️ WARNING: Document already exists for user \(result.user.uid)")
                }
                
                // Attempt to write data
                try await docRef.setData(userData)
                print("✅ SUCCESS: User data stored in Firestore")
                
                isAuthenticated = true
                errorMessage = nil
                print("🎉 SUCCESS: User creation complete - ID: \(result.user.uid)")
            } catch let firestoreError as NSError {
                print("""
                    ❌ FIRESTORE ERROR:
                    - Error Code: \(firestoreError.code)
                    - Domain: \(firestoreError.domain)
                    - Description: \(firestoreError.localizedDescription)
                    - Debug Info: \(String(describing: firestoreError.userInfo))
                    """)
                
                // If Firestore fails, still allow auth but log the error
                isAuthenticated = true
                errorMessage = "Account created but profile setup incomplete. Please try again later."
            }
        } catch {
            print("""
                ❌ AUTH ERROR during user creation:
                - Error: \(error.localizedDescription)
                - Debug Description: \(String(describing: error))
                """)
            handleAuthError(error)
        }
    }
    
    func signOut() {
        print("👋 DEBUG: Attempting sign out...")
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            errorMessage = nil
            print("✅ SUCCESS: User signed out")
        } catch {
            print("❌ ERROR during sign out: \(error)")
            handleAuthError(error)
        }
    }
    
    private func handleAuthError(_ error: Error) {
        let authError = error as NSError
        print("""
            🔍 DEBUG: Processing auth error...
            - Code: \(authError.code)
            - Domain: \(authError.domain)
            - Description: \(authError.localizedDescription)
            - User Info: \(authError.userInfo)
            """)
        
        switch authError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            errorMessage = "This email is already registered. Please try logging in."
            print("📢 EMAIL_IN_USE: Email already registered")
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "Please enter a valid email address."
            print("📢 INVALID_EMAIL: Email format invalid")
        case AuthErrorCode.weakPassword.rawValue:
            errorMessage = "Your password is too weak. Please use at least 6 characters."
            print("📢 WEAK_PASSWORD: Password requirements not met")
        case AuthErrorCode.wrongPassword.rawValue:
            errorMessage = "Incorrect password. Please try again."
            print("📢 WRONG_PASSWORD: Authentication failed")
        case AuthErrorCode.userNotFound.rawValue:
            errorMessage = "No account found with this email. Please sign up."
            print("📢 USER_NOT_FOUND: Email not registered")
        default:
            errorMessage = error.localizedDescription
            print("📢 UNKNOWN_ERROR: \(error.localizedDescription)")
        }
    }
} 