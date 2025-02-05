import SwiftUI
import FirebaseAuth

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var isShowingSignUp = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo/Title
                    Text("New-AI")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                    
                    // Authentication Forms
                    if isShowingSignUp {
                        SignUpView(viewModel: viewModel)
                            .transition(.move(edge: .trailing))
                    } else {
                        SignInView(viewModel: viewModel)
                            .transition(.move(edge: .leading))
                    }
                    
                    // Toggle Button
                    Button(action: {
                        withAnimation {
                            isShowingSignUp.toggle()
                        }
                    }) {
                        Text(isShowingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.white)
                            .underline()
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
        }
    }
}

#Preview {
    AuthenticationView(viewModel: AuthenticationViewModel())
} 