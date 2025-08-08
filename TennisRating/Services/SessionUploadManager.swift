import Foundation
import SwiftUI

// MARK: - Upload Status
enum UploadStatus: Equatable {
    case idle
    case uploading
    case success(String) // sessionId
    case failed(String)  // error message
    case retry
    
    static func == (lhs: UploadStatus, rhs: UploadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.uploading, .uploading),
             (.retry, .retry):
            return true
        case (.success(let lhsId), .success(let rhsId)):
            return lhsId == rhsId
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Session Upload Manager
@MainActor
class SessionUploadManager: ObservableObject {
    static let shared = SessionUploadManager()
    
    @Published var uploadStatus: UploadStatus = .idle
    @Published var uploadProgress: Double = 0.0
    @Published var showUploadAlert = false
    @Published var pendingUploads: [SessionData] = []
    
    private let networkManager = NetworkManager.shared
    private let authManager = AuthManager.shared
    
    // Store failed uploads for retry
    private var failedUploads: [SessionData] = []
    
    private init() {
        loadPendingUploads()
    }
    
    // MARK: - Upload Session
    func uploadSession(_ sessionData: SessionData, showProgress: Bool = true) async {
        guard authManager.isAuthenticated else {
            uploadStatus = .failed("Please log in to upload sessions")
            return
        }
        
        if showProgress {
            uploadStatus = .uploading
            uploadProgress = 0.0
        }
        
        // Simulate upload progress
        await simulateProgress()
        
        // Attempt upload
        if let sessionId = await networkManager.uploadSession(sessionData) {
            uploadStatus = .success(sessionId)
            removeFromPending(sessionData)
            
            // Store successful upload locally for history
            saveUploadedSession(sessionData, sessionId: sessionId)
            
            if showProgress {
                showUploadAlert = true
            }
            
            print("✅ Session uploaded successfully: \(sessionId)")
        } else {
            uploadStatus = .failed("Upload failed. Session saved for retry.")
            addToPending(sessionData)
            
            if showProgress {
                showUploadAlert = true
            }
        }
    }
    
    // MARK: - Batch Upload Pending Sessions
    func uploadPendingSessions() async {
        guard !pendingUploads.isEmpty else { return }
        
        uploadStatus = .uploading
        uploadProgress = 0.0
        
        let totalSessions = pendingUploads.count
        var uploaded = 0
        
        for sessionData in pendingUploads {
            await uploadSession(sessionData, showProgress: false)
            
            uploaded += 1
            uploadProgress = Double(uploaded) / Double(totalSessions)
            
            // Small delay between uploads
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        if pendingUploads.isEmpty {
            uploadStatus = .success("All sessions uploaded")
        } else {
            uploadStatus = .failed("\(pendingUploads.count) sessions still pending")
        }
        
        showUploadAlert = true
    }
    
    // MARK: - Auto Upload
    func autoUploadSession(_ sessionData: SessionData) {
        Task {
            await uploadSession(sessionData, showProgress: false)
        }
    }
    
    // MARK: - Retry Failed Uploads
    func retryFailedUploads() {
        Task {
            await uploadPendingSessions()
        }
    }
    
    // MARK: - Progress Simulation
    private func simulateProgress() async {
        uploadProgress = 0.0
        
        // Simulate upload progress
        for i in 1...10 {
            uploadProgress = Double(i) / 10.0
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    // MARK: - Pending Uploads Management
    private func addToPending(_ sessionData: SessionData) {
        if !pendingUploads.contains(where: { $0.id == sessionData.id }) {
            pendingUploads.append(sessionData)
            savePendingUploads()
        }
    }
    
    private func removeFromPending(_ sessionData: SessionData) {
        pendingUploads.removeAll { $0.id == sessionData.id }
        savePendingUploads()
    }
    
    // MARK: - Persistence
    private func savePendingUploads() {
        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: "pending_uploads")
        }
    }
    
    private func loadPendingUploads() {
        if let data = UserDefaults.standard.data(forKey: "pending_uploads"),
           let sessions = try? JSONDecoder().decode([SessionData].self, from: data) {
            pendingUploads = sessions
        }
    }
    
    private func saveUploadedSession(_ sessionData: SessionData, sessionId: String) {
        var uploadedSessions = getUploadedSessions()
        
        // Create uploaded session record
        let uploadRecord = UploadedSession(
            sessionData: sessionData,
            sessionId: sessionId,
            uploadDate: Date()
        )
        
        uploadedSessions.append(uploadRecord)
        
        // Keep only last 50 uploaded sessions
        if uploadedSessions.count > 50 {
            uploadedSessions = Array(uploadedSessions.suffix(50))
        }
        
        if let encoded = try? JSONEncoder().encode(uploadedSessions) {
            UserDefaults.standard.set(encoded, forKey: "uploaded_sessions")
        }
    }
    
    func getUploadedSessions() -> [UploadedSession] {
        if let data = UserDefaults.standard.data(forKey: "uploaded_sessions"),
           let sessions = try? JSONDecoder().decode([UploadedSession].self, from: data) {
            return sessions
        }
        return []
    }
    
    // MARK: - Upload Statistics
    var uploadStats: UploadStats {
        let uploaded = getUploadedSessions()
        let pending = pendingUploads.count
        let total = uploaded.count + pending
        
        return UploadStats(
            totalSessions: total,
            uploadedSessions: uploaded.count,
            pendingSessions: pending,
            successRate: total > 0 ? Double(uploaded.count) / Double(total) : 0.0,
            lastUploadDate: uploaded.last?.uploadDate
        )
    }
    
    // MARK: - Reset
    func clearAllData() {
        pendingUploads.removeAll()
        UserDefaults.standard.removeObject(forKey: "pending_uploads")
        UserDefaults.standard.removeObject(forKey: "uploaded_sessions")
        uploadStatus = .idle
    }
}

// MARK: - Supporting Models
struct UploadedSession: Codable, Identifiable {
    let id = UUID()
    let sessionData: SessionData
    let sessionId: String
    let uploadDate: Date
}

struct UploadStats {
    let totalSessions: Int
    let uploadedSessions: Int
    let pendingSessions: Int
    let successRate: Double
    let lastUploadDate: Date?
    
    var successRatePercentage: Int {
        Int(successRate * 100)
    }
}
