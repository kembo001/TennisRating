import Foundation
import Network

// MARK: - API Configuration
struct APIConfig {
    static let baseURL: String = {
        #if DEBUG
        // Development - Reid's server IP
        return "http://198.199.75.53:3000"
        #else
        // Production
        return "https://api.tennisrating.com"
        #endif
    }()
    
    static let apiVersion = "v1"
    static let timeout: TimeInterval = 30.0
}

// MARK: - API Error Types
enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String)
    case unauthorized
    case noInternetConnection
    case timeout
    case unknown
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.noData, .noData),
             (.unauthorized, .unauthorized),
             (.noInternetConnection, .noInternetConnection),
             (.timeout, .timeout),
             (.unknown, .unknown):
            return true
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .noInternetConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Client
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout * 2
        
        self.session = URLSession(configuration: config)
        
        // Start network monitoring
        startNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Generic Request Method
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        // Check network connectivity
        guard isConnected else {
            throw APIError.noInternetConnection
        }
        
        // Create URL
        guard let url = createURL(for: endpoint) else {
            logRequest(endpoint: endpoint, method: method, error: "Invalid URL")
            throw APIError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth token if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body for POST/PUT requests
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                logRequest(endpoint: endpoint, method: method, error: "Failed to serialize body")
                throw APIError.networkError(error)
            }
        }
        
        logRequest(endpoint: endpoint, method: method, body: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Handle HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown
            }
            
            logResponse(endpoint: endpoint, statusCode: httpResponse.statusCode, data: data)
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return decoded
                } catch {
                    throw APIError.decodingError(error)
                }
                
            case 401:
                // Unauthorized - clear token and throw error
                TokenManager.shared.clearToken()
                throw APIError.unauthorized
                
            case 400...499:
                // Client error - try to get error message
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.serverError(httpResponse.statusCode, errorResponse.error ?? "Client error")
                } else {
                    throw APIError.serverError(httpResponse.statusCode, "Client error")
                }
                
            case 500...599:
                // Server error
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.serverError(httpResponse.statusCode, errorResponse.error ?? "Server error")
                } else {
                    throw APIError.serverError(httpResponse.statusCode, "Server error")
                }
                
            default:
                throw APIError.serverError(httpResponse.statusCode, "Unexpected status code")
            }
            
        } catch let urlError as URLError {
            logRequest(endpoint: endpoint, method: method, error: urlError.localizedDescription)
            
            switch urlError.code {
            case .timedOut:
                throw APIError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.noInternetConnection
            default:
                throw APIError.networkError(urlError)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createURL(for endpoint: String) -> URL? {
        let cleanEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        let urlString = "\(APIConfig.baseURL)/\(cleanEndpoint)"
        return URL(string: urlString)
    }
    
    // MARK: - Request Logging
    private func logRequest(endpoint: String, method: HTTPMethod, body: [String: Any]? = nil, error: String? = nil) {
        #if DEBUG
        print("🌐 API Request: \(method.rawValue) \(endpoint)")
        if let body = body {
            print("📤 Body: \(body)")
        }
        if let error = error {
            print("❌ Error: \(error)")
        }
        #endif
    }
    
    private func logResponse(endpoint: String, statusCode: Int, data: Data) {
        #if DEBUG
        print("🌐 API Response: \(endpoint) - Status: \(statusCode)")
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Response: \(jsonString)")
        }
        #endif
    }
}

// MARK: - Error Response Model
struct APIErrorResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - Token Manager
class TokenManager {
    static let shared = TokenManager()
    
    private let keychain = "TennisRating"
    private let tokenKey = "auth_token"
    
    private init() {}
    
    func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrService as String: keychain,
            kSecValueData as String: data
        ] as [String: Any]
        
        // Delete any existing token first
        SecItemDelete(query as CFDictionary)
        
        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        
        #if DEBUG
        if status == errSecSuccess {
            print("🔐 Token saved successfully")
        } else {
            print("🔐 Failed to save token: \(status)")
        }
        #endif
    }
    
    func getToken() -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrService as String: keychain,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func clearToken() {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrService as String: keychain
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        
        #if DEBUG
        if status == errSecSuccess {
            print("🔐 Token cleared successfully")
        }
        #endif
    }
    
    var isLoggedIn: Bool {
        return getToken() != nil
    }
}

// MARK: - API Client Extensions for Specific Endpoints

extension APIClient {
    
    // MARK: - Health Check
    func healthCheck() async throws -> HealthResponse {
        return try await request(
            endpoint: "health",
            method: .GET,
            responseType: HealthResponse.self
        )
    }
    
    // MARK: - Authentication
    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = [
            "email": email,
            "password": password,
            "name": name
        ]
        
        return try await request(
            endpoint: "api/auth/register",
            method: .POST,
            body: body,
            responseType: AuthResponse.self
        )
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = [
            "email": email,
            "password": password
        ]
        
        return try await request(
            endpoint: "api/auth/login",
            method: .POST,
            body: body,
            responseType: AuthResponse.self
        )
    }
    
    func logout() async throws -> MessageResponse {
        return try await request(
            endpoint: "api/auth/logout",
            method: .POST,
            responseType: MessageResponse.self
        )
    }
    
    // MARK: - Sessions
    func uploadSession(_ sessionData: SessionData) async throws -> SessionUploadResponse {
        // Convert SessionData to dictionary
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(sessionData)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        return try await request(
            endpoint: "api/sessions",
            method: .POST,
            body: json,
            responseType: SessionUploadResponse.self
        )
    }
    
    func getUserSessions(userId: String) async throws -> SessionHistoryResponse {
        return try await request(
            endpoint: "api/sessions/\(userId)",
            method: .GET,
            responseType: SessionHistoryResponse.self
        )
    }
    
    func getSession(sessionId: String) async throws -> SessionDetailResponse {
        return try await request(
            endpoint: "api/sessions/session/\(sessionId)",
            method: .GET,
            responseType: SessionDetailResponse.self
        )
    }
    
    // MARK: - Statistics
    func getUserStats(userId: String) async throws -> UserStatsResponse {
        return try await request(
            endpoint: "api/stats/\(userId)",
            method: .GET,
            responseType: UserStatsResponse.self
        )
    }
    
    func getUserProgress(userId: String, period: String = "month") async throws -> ProgressResponse {
        return try await request(
            endpoint: "api/stats/\(userId)/progress?period=\(period)",
            method: .GET,
            responseType: ProgressResponse.self
        )
    }
}

// MARK: - Response Models
struct HealthResponse: Codable {
    let status: String
    let timestamp: String
    let service: String
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
    let user: User?
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
}

struct MessageResponse: Codable {
    let success: Bool
    let message: String
}

struct SessionUploadResponse: Codable {
    let success: Bool
    let message: String
    let sessionId: String?
}

struct SessionHistoryResponse: Codable {
    let success: Bool
    let sessions: [SessionData]
}

struct SessionDetailResponse: Codable {
    let success: Bool
    let session: SessionData?
}

struct UserStatsResponse: Codable {
    let success: Bool
    let stats: UserStats
}

struct UserStats: Codable {
    let totalSessions: Int
    let totalShots: Int
    let averageRating: Double
    let bestRating: Int
    let improvementTrend: Double
    let swingBreakdown: SwingBreakdown
    let recentActivity: [SessionData]
}

struct SwingBreakdown: Codable {
    let forehand: Int
    let backhand: Int
    let serve: Int
}

struct ProgressResponse: Codable {
    let success: Bool
    let progress: ProgressData
}

struct ProgressData: Codable {
    let period: String
    let dataPoints: [ProgressPoint]
}

struct ProgressPoint: Codable {
    let date: String
    let rating: Double
    let shots: Int
}
