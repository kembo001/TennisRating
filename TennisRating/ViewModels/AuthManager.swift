import Foundation
import SwiftUI

// MARK: - Authentication State
enum AuthState {
    case loading
    case unauthenticated
    case authenticated(User)
}

// MARK: - Auth Manager
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var authState: AuthState = .loading
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Enable real server mode now that Reid's backend is ready!
    @Published var useMockData = false // Changed from true to false
    
    private let networkManager = NetworkManager.shared
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Current User
    var currentUser: User? {
        if case .authenticated(let user) = authState {
            return user
        }
        return nil
    }
    
    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }
    
    // MARK: - Authentication Methods
    
    func register(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        
        if useMockData {
            // Mock registration - simulate network delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Simulate success
            let mockUser = User(id: UUID().uuidString, email: email, name: name)
            let mockToken = "mock_jwt_token_\(UUID().uuidString)"
            
            TokenManager.shared.saveToken(mockToken)
            authState = .authenticated(mockUser)
            
            print("✅ Mock registration successful for \(email)")
        } else {
            // Real network request
            if let response = await networkManager.register(email: email, password: password, name: name) {
                if response.success, let user = response.user {
                    authState = .authenticated(user)
                } else {
                    errorMessage = response.message ?? "Registration failed"
                }
            } else {
                errorMessage = "Registration failed. Please try again."
            }
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        if useMockData {
            // Mock login - simulate network delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Simulate login validation
            if email.contains("@") && password.count >= 6 {
                let mockUser = User(id: "mock_user_123", email: email, name: "Test User")
                let mockToken = "mock_jwt_token_\(UUID().uuidString)"
                
                TokenManager.shared.saveToken(mockToken)
                authState = .authenticated(mockUser)
                
                print("✅ Mock login successful for \(email)")
            } else {
                errorMessage = "Invalid email or password"
            }
        } else {
            // Real network request
            if let response = await networkManager.login(email: email, password: password) {
                if response.success, let user = response.user {
                    authState = .authenticated(user)
                } else {
                    errorMessage = response.message ?? "Invalid email or password"
                }
            } else {
                errorMessage = "Login failed. Please try again."
            }
        }
        
        isLoading = false
    }
    
    func logout() async {
        isLoading = true
        
        if useMockData {
            // Mock logout
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            TokenManager.shared.clearToken()
            authState = .unauthenticated
            print("✅ Mock logout successful")
        } else {
            // Real network request
            await networkManager.logout()
            authState = .unauthenticated
        }
        
        isLoading = false
    }
    
    // MARK: - Auth Status Check
    
    private func checkAuthStatus() {
        if TokenManager.shared.isLoggedIn {
            if useMockData {
                // Create mock user from stored token
                let mockUser = User(id: "mock_user_123", email: "user@example.com", name: "Test User")
                authState = .authenticated(mockUser)
            } else {
                // In real implementation, validate token with server
                // For now, assume valid if token exists
                let mockUser = User(id: "user_123", email: "user@example.com", name: "Current User")
                authState = .authenticated(mockUser)
            }
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Switch to Real Server
    
    func switchToRealServer() {
        useMockData = false
        print("🔄 Switched to real server mode")
    }
    
    func switchToMockMode() {
        useMockData = true
        print("🔄 Switched to mock mode")
    }
    
    // MARK: - Validation Helpers
    
    func validateEmail(_ email: String) -> String? {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        
        if email.isEmpty {
            return "Email is required"
        } else if !emailPredicate.evaluate(with: email) {
            return "Please enter a valid email"
        }
        return nil
    }
    
    func validatePassword(_ password: String) -> String? {
        if password.isEmpty {
            return "Password is required"
        } else if password.count < 6 {
            return "Password must be at least 6 characters"
        }
        return nil
    }
    
    func validateName(_ name: String) -> String? {
        if name.isEmpty {
            return "Name is required"
        } else if name.count < 2 {
            return "Name must be at least 2 characters"
        }
        return nil
    }
    
    // MARK: - Clear Error
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Auth State View Modifier
struct AuthStateHandler: ViewModifier {
    @ObservedObject var authManager: AuthManager
    
    func body(content: Content) -> some View {
        Group {
            switch authManager.authState {
            case .loading:
                LoadingView()
            case .unauthenticated:
                AuthenticationView()
            case .authenticated:
                content
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func handleAuthState(_ authManager: AuthManager = AuthManager.shared) -> some View {
        modifier(AuthStateHandler(authManager: authManager))
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.tennis")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Tennis Rating")
                .font(.largeTitle)
                .bold()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
