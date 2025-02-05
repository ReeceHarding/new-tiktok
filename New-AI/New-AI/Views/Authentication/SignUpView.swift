import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Username Field
            TextField("Username", text: $username)
                .textFieldStyle(CustomTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            // Email Field
            TextField("Email", text: $email)
                .textFieldStyle(CustomTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            // Password Field
            SecureField("Password", text: $password)
                .textFieldStyle(CustomTextFieldStyle())
            
            // Error Message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            // Sign Up Button
            Button(action: {
                Task {
                    await viewModel.createUser(withEmail: email, password: password, username: username)
                }
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .disabled(email.isEmpty || password.isEmpty || username.isEmpty)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SignUpView(viewModel: AuthenticationViewModel())
    }
} 