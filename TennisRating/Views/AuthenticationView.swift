import SwiftUI

// MARK: - Authentication View
struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showingRegister = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Tennis Rating")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("AI-Powered Tennis Coach")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Mock Mode Indicator (remove this when using real server)
                if authManager.useMockData {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(.orange)
                        Text("Demo Mode - No server required")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Auth Forms
                if showingRegister {
                    RegisterView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                }
                
                // Toggle between login/register
                HStack {
                    Text(showingRegister ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.secondary)
                    
                  if #available(iOS 16.0, *) {
                    Button(showingRegister ? "Sign In" : "Sign Up") {
                      withAnimation(.easeInOut(duration: 0.3)) {
                        showingRegister.toggle()
                        authManager.clearError()
                      }
                    }
                    .foregroundColor(.blue)
                    .bold()
                  } else {
                    // Fallback on earlier versions
                  }
                }
                .padding(.bottom, 30)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome Back")
                .font(.title2)
                .bold()
            
            VStack(spacing: 15) {
                // Email Field
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: email) { _ in
                            emailError = nil
                            authManager.clearError()
                        }
                    
                    if let error = emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 5) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .onChange(of: password) { _ in
                            passwordError = nil
                            authManager.clearError()
                        }
                    
                    if let error = passwordError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Error Message
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Login Button
            Button(action: loginTapped) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(authManager.isLoading ? "Signing In..." : "Sign In")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || authManager.isLoading)
            
            // Demo Helper Text
            if authManager.useMockData {
                VStack(spacing: 5) {
                    Text("Demo Mode:")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                    
                    Text("Use any email and password (6+ chars)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func loginTapped() {
        // Validate form
        emailError = authManager.validateEmail(email)
        passwordError = authManager.validatePassword(password)
        
        // If validation passes, attempt login
        if emailError == nil && passwordError == nil {
            Task {
                await authManager.login(email: email, password: password)
            }
        }
    }
}

// MARK: - Register View
struct RegisterView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.title2)
                .bold()
            
            VStack(spacing: 15) {
                // Name Field
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _ in
                            nameError = nil
                            authManager.clearError()
                        }
                    
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: email) { _ in
                            emailError = nil
                            authManager.clearError()
                        }
                    
                    if let error = emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 5) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .onChange(of: password) { _ in
                            passwordError = nil
                            confirmPasswordError = nil
                            authManager.clearError()
                        }
                    
                    if let error = passwordError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 5) {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .onChange(of: confirmPassword) { _ in
                            confirmPasswordError = nil
                            authManager.clearError()
                        }
                    
                    if let error = confirmPasswordError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Error Message
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Register Button
            Button(action: registerTapped) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(authManager.isLoading ? "Creating Account..." : "Create Account")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || authManager.isLoading)
            
            // Demo Helper Text
            if authManager.useMockData {
                VStack(spacing: 5) {
                    Text("Demo Mode:")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                    
                    Text("Account will be created locally")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }
    
    private func registerTapped() {
        // Validate form
        nameError = authManager.validateName(name)
        emailError = authManager.validateEmail(email)
        passwordError = authManager.validatePassword(password)
        
        if password != confirmPassword {
            confirmPasswordError = "Passwords don't match"
        }
        
        // If validation passes, attempt registration
        if nameError == nil && emailError == nil && passwordError == nil && confirmPasswordError == nil {
            Task {
                await authManager.register(email: email, password: password, name: name)
            }
        }
    }
}

// MARK: - Custom Text Field Style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - User Profile View (for testing authenticated state)
struct UserProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if let user = authManager.currentUser {
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(user.name)
                        .font(.title2)
                        .bold()
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Server Mode Toggle (remove in production)
                if authManager.useMockData {
                    VStack {
                        Text("Demo Mode Active")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Button("Switch to Real Server") {
                            authManager.switchToRealServer()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    Task {
                        await authManager.logout()
                    }
                }) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(authManager.isLoading ? "Signing Out..." : "Sign Out")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("Profile")
    }
}

// MARK: - Preview
#Preview {
    AuthenticationView()
}
