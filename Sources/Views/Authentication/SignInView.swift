import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
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
            
            // Sign In Button
            Button(action: {
                Task {
                    await viewModel.signIn(withEmail: email, password: password)
                }
            }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .disabled(email.isEmpty || password.isEmpty)
        }
        .padding(.horizontal)
    }
}

// Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
            .accentColor(.white)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SignInView(viewModel: AuthenticationViewModel())
    }
} 