import Foundation
import SwiftUI

// MARK: - NetworkManager
/// Simplified interface for network operations
/// Acts as a wrapper around APIClient with common patterns
@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let apiClient = APIClient.shared
    
    @Published var isLoading = false
    @Published var lastError: APIError?
    @Published var isConnected = true
    
    private init() {
        // Observe connectivity changes
        apiClient.$isConnected
            .assign(to: &$isConnected)
    }
    
    // MARK: - Helper Methods
    
    /// Performs a network request with loading state management
    private func performRequest<T>(_ request: @escaping () async throws -> T) async -> Result<T, APIError> {
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let result = try await request()
            return .success(result)
        } catch let apiError as APIError {
            lastError = apiError
            return .failure(apiError)
        } catch {
            let apiError = APIError.networkError(error)
            lastError = apiError
            return .failure(apiError)
        }
    }
    
    /// Shows error alert for failed requests
    func showError(_ error: APIError) {
        DispatchQueue.main.async {
            // You can customize this to show your preferred error UI
            print("❌ Network Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Health Check
    
    func testConnection() async -> Bool {
        let result = await performRequest {
          try await self.apiClient.healthCheck()
        }
        
        switch result {
        case .success:
            print("✅ Server connection successful")
            return true
        case .failure(let error):
            print("❌ Server connection failed: \(error.localizedDescription)")
            showError(error)
            return false
        }
    }
    
    // MARK: - Authentication
    
    func register(email: String, password: String, name: String) async -> AuthResponse? {
        let result = await performRequest {
          try await self.apiClient.register(email: email, password: password, name: name)
        }
        
        switch result {
        case .success(let response):
            if let token = response.token {
                TokenManager.shared.saveToken(token)
                print("✅ Registration successful")
            }
            return response
        case .failure(let error):
            showError(error)
            return nil
        }
    }
    
    func login(email: String, password: String) async -> AuthResponse? {
        let result = await performRequest {
          try await self.apiClient.login(email: email, password: password)
        }
        
        switch result {
        case .success(let response):
            if let token = response.token {
                TokenManager.shared.saveToken(token)
                print("✅ Login successful")
            }
            return response
        case .failure(let error):
            showError(error)
            return nil
        }
    }
    
    func logout() async -> Bool {
        let result = await performRequest {
          try await self.apiClient.logout()
        }
        
        switch result {
        case .success:
            TokenManager.shared.clearToken()
            print("✅ Logout successful")
            return true
        case .failure(let error):
            showError(error)
            // Clear token anyway on logout
            TokenManager.shared.clearToken()
            return false
        }
    }
    
    // MARK: - Session Management
    
    func uploadSession(_ sessionData: SessionData) async -> String? {
        let result = await performRequest {
          try await self.apiClient.uploadSession(sessionData)
        }
        
        switch result {
        case .success(let response):
            print("✅ Session uploaded successfully")
            return response.sessionId
        case .failure(let error):
            showError(error)
            return nil
        }
    }
    
    func getUserSessions(userId: String) async -> [SessionData] {
        let result = await performRequest {
          try await self.apiClient.getUserSessions(userId: userId)
        }
        
        switch result {
        case .success(let response):
            return response.sessions
        case .failure(let error):
            showError(error)
            return []
        }
    }
    
    func getSession(sessionId: String) async -> SessionData? {
        let result = await performRequest {
          try await self.apiClient.getSession(sessionId: sessionId)
        }
        
        switch result {
        case .success(let response):
            return response.session
        case .failure(let error):
            showError(error)
            return nil
        }
    }
    
    // MARK: - Statistics
    
    func getUserStats(userId: String) async -> UserStats? {
        let result = await performRequest {
          try await self.apiClient.getUserStats(userId: userId)
        }
        
        switch result {
        case .success(let response):
            return response.stats
        case .failure(let error):
            showError(error)
            return nil
        }
    }
    
    func getUserProgress(userId: String, period: String = "month") async -> ProgressData? {
        let result = await performRequest {
          try await self.apiClient.getUserProgress(userId: userId, period: period)
        }
        
        switch result {
        case .success(let response):
            return response.progress
        case .failure(let error):
            showError(error)
            return nil
        }
    }
    
    // MARK: - Retry Logic
    
    func retryLastFailedRequest() {
        // Implement retry logic based on lastError if needed
        // This is a placeholder for more sophisticated retry mechanisms
        if let error = lastError {
            print("🔄 Retrying last failed request: \(error.localizedDescription)")
        }
    }
}

// MARK: - Error Handling View Modifier
struct NetworkErrorHandler: ViewModifier {
    @ObservedObject var networkManager: NetworkManager
    @State private var showingError = false
    
    func body(content: Content) -> some View {
      if #available(iOS 17.0, *) {
        content
          .alert("Network Error", isPresented: $showingError) {
            Button("OK") {
              showingError = false
            }
            
            if networkManager.lastError != nil {
              Button("Retry") {
                networkManager.retryLastFailedRequest()
                showingError = false
              }
            }
          } message: {
            if let error = networkManager.lastError {
              Text(error.localizedDescription)
            }
          }
          .onChange(of: networkManager.lastError) { _, error in
            if error != nil {
              showingError = true
            }
          }
      } else {
        // Fallback on earlier versions
      }
    }
}

// MARK: - View Extension
extension View {
    func networkErrorHandler(_ networkManager: NetworkManager = NetworkManager.shared) -> some View {
        modifier(NetworkErrorHandler(networkManager: networkManager))
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    @ObservedObject var networkManager = NetworkManager.shared
    
    var body: some View {
        Group {
            if !networkManager.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                    Text("No Internet Connection")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Usage Examples in Comments
/*
 
 // MARK: - Example Usage in Views
 
 // 1. In your login view:
 struct LoginView: View {
     @StateObject private var networkManager = NetworkManager.shared
     @State private var email = ""
     @State private var password = ""
     
     var body: some View {
         VStack {
             TextField("Email", text: $email)
             SecureField("Password", text: $password)
             
             Button("Login") {
                 Task {
                     await networkManager.login(email: email, password: password)
                 }
             }
             .disabled(networkManager.isLoading)
             
             if networkManager.isLoading {
                 ProgressView()
             }
             
             ConnectionStatusView()
         }
         .networkErrorHandler()
     }
 }
 
 // 2. In your session upload:
 struct ResultsView: View {
     let sessionData: SessionData
     @StateObject private var networkManager = NetworkManager.shared
     
     var body: some View {
         VStack {
             // Your results UI
             
             Button("Upload Session") {
                 Task {
                     if let sessionId = await networkManager.uploadSession(sessionData) {
                         print("Session uploaded with ID: \(sessionId)")
                     }
                 }
             }
             .disabled(networkManager.isLoading)
         }
         .networkErrorHandler()
     }
 }
 
 // 3. Test connection on app startup:
 struct ContentView: View {
     @StateObject private var networkManager = NetworkManager.shared
     @State private var connectionTested = false
     
     var body: some View {
         VStack {
             // Your app content
         }
         .task {
             if !connectionTested {
                 connectionTested = true
                 await networkManager.testConnection()
             }
         }
     }
 }
 
 */
