import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profile Information")) {
                    if let user = viewModel.userProfile {
                        Text("Username: \(user.username)")
                        Text("Email: \(user.email)")
                        if let bio = user.bio {
                            Text("Bio: \(bio)")
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.signOut()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .onAppear {
                Task {
                    await viewModel.fetchUserProfile()
                }
            }
        }
    }
} 