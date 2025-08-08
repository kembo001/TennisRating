import Foundation
import SwiftUI

// MARK: - Session History Manager
@MainActor
class SessionHistoryManager: ObservableObject {
    static let shared = SessionHistoryManager()
    
    @Published var sessions: [SessionData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefresh: Date?
    
    // Filtering and sorting
    @Published var selectedPeriod: TimePeriod = .all
    @Published var sortBy: SortOption = .date
    @Published var sortAscending = false
    
    private let networkManager = NetworkManager.shared
    private let authManager = AuthManager.shared
    private let uploadManager = SessionUploadManager.shared
    
    enum TimePeriod: String, CaseIterable {
        case all = "All Time"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        
        var dateRange: DateInterval? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all:
                return nil
            case .week:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                return DateInterval(start: startOfWeek, end: now)
            case .month:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return DateInterval(start: startOfMonth, end: now)
            case .year:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                return DateInterval(start: startOfYear, end: now)
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case date = "Date"
        case rating = "Rating"
        case shots = "Total Shots"
        case duration = "Duration"
        case successRate = "Success Rate"
    }
    
    private init() {
        loadLocalSessions()
    }
    
    // MARK: - Load Sessions
    func loadSessions(refresh: Bool = false) async {
        guard authManager.isAuthenticated else {
            loadLocalSessions()
            return
        }
        
        if refresh || sessions.isEmpty {
            isLoading = true
            errorMessage = nil
        }
        
        // Load from server
        if let userId = authManager.currentUser?.id {
            let remoteSessions = await networkManager.getUserSessions(userId: userId)
            
            if !remoteSessions.isEmpty {
                sessions = remoteSessions
                saveSessionsLocally(remoteSessions)
            } else if !refresh {
                // If no remote sessions and not refreshing, load local
                loadLocalSessions()
            }
        }
        
        // Also include local sessions (for demo mode or offline sessions)
        let localSessions = getLocalSessions()
        
        // Merge remote and local sessions (avoiding duplicates)
        var allSessions = sessions
        for localSession in localSessions {
            if !allSessions.contains(where: { $0.id == localSession.id }) {
                allSessions.append(localSession)
            }
        }
        
        sessions = allSessions
        applySortingAndFiltering()
        
        isLoading = false
        lastRefresh = Date()
    }
    
    // MARK: - Local Session Management
    private func loadLocalSessions() {
        // Load uploaded sessions
        let uploadedSessions = uploadManager.getUploadedSessions().map { $0.sessionData }
        
        // Load any additional local sessions
        let localSessions = getLocalSessions()
        
        // Combine all sessions
        var allSessions = uploadedSessions
        for localSession in localSessions {
            if !allSessions.contains(where: { $0.id == localSession.id }) {
                allSessions.append(localSession)
            }
        }
        
        sessions = allSessions
        applySortingAndFiltering()
    }
    
    private func getLocalSessions() -> [SessionData] {
        if let data = UserDefaults.standard.data(forKey: "local_sessions"),
           let sessions = try? JSONDecoder().decode([SessionData].self, from: data) {
            return sessions
        }
        return []
    }
    
    func saveSessionLocally(_ sessionData: SessionData) {
        var localSessions = getLocalSessions()
        
        // Add new session if not already exists
        if !localSessions.contains(where: { $0.id == sessionData.id }) {
            localSessions.append(sessionData)
            
            // Keep only last 100 sessions locally
            if localSessions.count > 100 {
                localSessions = Array(localSessions.suffix(100))
            }
            
            saveSessionsLocally(localSessions)
            
            // Reload to include new session
            Task {
                await loadSessions()
            }
        }
    }
    
    private func saveSessionsLocally(_ sessions: [SessionData]) {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "local_sessions")
        }
    }
    
    // MARK: - Filtering and Sorting
    var filteredSessions: [SessionData] {
        var filtered = sessions
        
        // Apply time period filter
        if let dateRange = selectedPeriod.dateRange {
            filtered = filtered.filter { session in
                dateRange.contains(session.timestamp)
            }
        }
        
        return filtered
    }
    
    private func applySortingAndFiltering() {
        var sorted = filteredSessions
        
        // Apply sorting
        switch sortBy {
        case .date:
            sorted.sort { sortAscending ? $0.timestamp < $1.timestamp : $0.timestamp > $1.timestamp }
        case .rating:
            sorted.sort { sortAscending ? $0.rating < $1.rating : $0.rating > $1.rating }
        case .shots:
            sorted.sort { sortAscending ? $0.totalShots < $1.totalShots : $0.totalShots > $1.totalShots }
        case .duration:
            sorted.sort { sortAscending ? $0.sessionDuration < $1.sessionDuration : $0.sessionDuration > $1.sessionDuration }
        case .successRate:
            sorted.sort { sortAscending ? $0.successRate < $1.successRate : $0.successRate > $1.successRate }
        }
        
        sessions = sorted
    }
    
    func updateSortingAndFiltering() {
        applySortingAndFiltering()
    }
    
    // MARK: - Session Statistics
    var sessionStats: SessionHistoryStats {
        let filtered = filteredSessions
        
        guard !filtered.isEmpty else {
            return SessionHistoryStats(
                totalSessions: 0,
                totalShots: 0,
                averageRating: 0,
                bestRating: 0,
                totalDuration: 0,
                averageSuccessRate: 0,
                improvementTrend: 0,
                mostFrequentShot: "None"
            )
        }
        
        let totalSessions = filtered.count
        let totalShots = filtered.reduce(0) { $0 + $1.totalShots }
        let totalRating = filtered.reduce(0) { $0 + $1.rating }
        let averageRating = Double(totalRating) / Double(totalSessions)
        let bestRating = filtered.map { $0.rating }.max() ?? 0
        let totalDuration = filtered.reduce(0) { $0 + $1.sessionDuration }
        let averageSuccessRate = filtered.reduce(0) { $0 + $1.successRate } / Double(totalSessions)
        
        // Calculate improvement trend (last 5 vs first 5 sessions)
        let improvementTrend = calculateImprovementTrend(filtered)
        
        // Most frequent shot type
        let forehandTotal = filtered.reduce(0) { $0 + $1.forehandCount }
        let backhandTotal = filtered.reduce(0) { $0 + $1.backhandCount }
        let serveTotal = filtered.reduce(0) { $0 + $1.serveCount }
        
        let mostFrequentShot: String
        if forehandTotal >= backhandTotal && forehandTotal >= serveTotal {
            mostFrequentShot = "Forehand"
        } else if backhandTotal >= serveTotal {
            mostFrequentShot = "Backhand"
        } else if serveTotal > 0 {
            mostFrequentShot = "Serve"
        } else {
            mostFrequentShot = "Mixed"
        }
        
        return SessionHistoryStats(
            totalSessions: totalSessions,
            totalShots: totalShots,
            averageRating: averageRating,
            bestRating: bestRating,
            totalDuration: totalDuration,
            averageSuccessRate: averageSuccessRate,
            improvementTrend: improvementTrend,
            mostFrequentShot: mostFrequentShot
        )
    }
    
    private func calculateImprovementTrend(_ sessions: [SessionData]) -> Double {
        guard sessions.count >= 6 else { return 0 }
        
        let sortedSessions = sessions.sorted { $0.timestamp < $1.timestamp }
        let firstFive = Array(sortedSessions.prefix(5))
        let lastFive = Array(sortedSessions.suffix(5))
        
        let firstAverage = firstFive.reduce(0) { $0 + $1.rating } / 5
        let lastAverage = lastFive.reduce(0) { $0 + $1.rating } / 5
        
        return Double(lastAverage - firstAverage)
    }
    
    // MARK: - Refresh
    func refresh() {
        Task {
            await loadSessions(refresh: true)
        }
    }
    
    // MARK: - Clear Data
    func clearHistory() {
        sessions.removeAll()
        UserDefaults.standard.removeObject(forKey: "local_sessions")
        lastRefresh = nil
    }
}

// MARK: - Session History Stats
struct SessionHistoryStats {
    let totalSessions: Int
    let totalShots: Int
    let averageRating: Double
    let bestRating: Int
    let totalDuration: TimeInterval
    let averageSuccessRate: Double
    let improvementTrend: Double
    let mostFrequentShot: String
    
    var averageRatingFormatted: String {
        String(format: "%.1f", averageRating)
    }
    
    var averageSuccessRatePercentage: Int {
        Int(averageSuccessRate * 100)
    }
    
    var totalDurationFormatted: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var improvementTrendFormatted: String {
        let trend = improvementTrend
        if trend > 0.5 {
            return "📈 Improving (+\(String(format: "%.1f", trend)))"
        } else if trend < -0.5 {
            return "📉 Declining (\(String(format: "%.1f", trend)))"
        } else {
            return "➡️ Stable"
        }
    }
}
