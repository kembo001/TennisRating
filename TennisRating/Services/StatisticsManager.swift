import Foundation
import SwiftUI

// MARK: - Statistics Manager
@MainActor
class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()
    
    @Published var isLoading = false
    @Published var lastUpdate: Date?
    @Published var selectedTimeFrame: TimeFrame = .month
    
    private let historyManager = SessionHistoryManager.shared
    private let authManager = AuthManager.shared
    private let networkManager = NetworkManager.shared
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .all: return Int.max
            }
        }
        
        var dateRange: DateInterval {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return DateInterval(start: Date.distantPast, end: now)
            default:
                let startDate = calendar.date(byAdding: .day, value: -days, to: now) ?? now
                return DateInterval(start: startDate, end: now)
            }
        }
    }
    
    private init() {}
    
    // MARK: - Core Statistics
    var overallStats: OverallStatistics {
        let sessions = getFilteredSessions()
        return calculateOverallStats(from: sessions)
    }
    
    var performanceMetrics: PerformanceMetrics {
        let sessions = getFilteredSessions()
        return calculatePerformanceMetrics(from: sessions)
    }
    
    var progressData: [ProgressDataPoint] {
        let sessions = getFilteredSessions()
        return calculateProgressData(from: sessions)
    }
    
    var shotTypeDistribution: [ShotTypeData] {
        let sessions = getFilteredSessions()
        return calculateShotTypeDistribution(from: sessions)
    }
    
    var weeklyActivity: [WeeklyActivityData] {
        let sessions = getFilteredSessions()
        return calculateWeeklyActivity(from: sessions)
    }
    
    var skillProgression: [SkillProgressionData] {
        let sessions = getFilteredSessions()
        return calculateSkillProgression(from: sessions)
    }
    
    // MARK: - Data Filtering
    private func getFilteredSessions() -> [SessionData] {
        let allSessions = historyManager.sessions
        let dateRange = selectedTimeFrame.dateRange
        
        return allSessions.filter { session in
            dateRange.contains(session.timestamp)
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Statistics Calculations
    private func calculateOverallStats(from sessions: [SessionData]) -> OverallStatistics {
        guard !sessions.isEmpty else {
            return OverallStatistics(
                totalSessions: 0,
                totalShots: 0,
                totalPracticeTime: 0,
                averageRating: 0,
                bestRating: 0,
                averageSessionLength: 0,
                totalSuccessfulShots: 0,
                overallSuccessRate: 0,
                mostProductiveDay: "None",
                currentStreak: 0,
                longestStreak: 0
            )
        }
        
        let totalSessions = sessions.count
        let totalShots = sessions.reduce(0) { $0 + $1.totalShots }
        let totalSuccessfulShots = sessions.reduce(0) { $0 + $1.successfulShots }
        let totalPracticeTime = sessions.reduce(0) { $0 + $1.sessionDuration }
        let averageRating = sessions.reduce(0.0) { $0 + Double($1.rating) } / Double(totalSessions)
        let bestRating = sessions.map { $0.rating }.max() ?? 0
        let averageSessionLength = totalPracticeTime / Double(totalSessions)
        let overallSuccessRate = totalShots > 0 ? Double(totalSuccessfulShots) / Double(totalShots) : 0
        
        // Most productive day of week
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayGroups = Dictionary(grouping: sessions) { dayFormatter.string(from: $0.timestamp) }
        let mostProductiveDay = dayGroups.max { $0.value.count < $1.value.count }?.key ?? "None"
        
        // Calculate streaks
        let (currentStreak, longestStreak) = calculateStreaks(from: sessions)
        
        return OverallStatistics(
            totalSessions: totalSessions,
            totalShots: totalShots,
            totalPracticeTime: totalPracticeTime,
            averageRating: averageRating,
            bestRating: bestRating,
            averageSessionLength: averageSessionLength,
            totalSuccessfulShots: totalSuccessfulShots,
            overallSuccessRate: overallSuccessRate,
            mostProductiveDay: mostProductiveDay,
            currentStreak: currentStreak,
            longestStreak: longestStreak
        )
    }
    
    private func calculatePerformanceMetrics(from sessions: [SessionData]) -> PerformanceMetrics {
        guard !sessions.isEmpty else {
            return PerformanceMetrics(
                consistency: 0,
                improvement: 0,
                efficiency: 0,
                volume: 0,
                overallScore: 0
            )
        }
        
        // Consistency: how consistent are success rates across sessions
        let successRates = sessions.map { $0.successRate }
        let avgSuccessRate = successRates.reduce(0, +) / Double(successRates.count)
        let variance = successRates.reduce(0) { $0 + pow($1 - avgSuccessRate, 2) } / Double(successRates.count)
        let consistency = max(0, 1 - sqrt(variance)) * 100
        
        // Improvement: trend of ratings over time
        let improvement = calculateImprovementTrend(from: sessions)
        
        // Efficiency: successful shots per minute
        let totalSuccessfulShots = sessions.reduce(0) { $0 + $1.successfulShots }
        let totalTime = sessions.reduce(0) { $0 + $1.sessionDuration } / 60 // in minutes
        let efficiency = totalTime > 0 ? Double(totalSuccessfulShots) / totalTime : 0
        
        // Volume: sessions per week
        let timeSpan = sessions.last!.timestamp.timeIntervalSince(sessions.first!.timestamp)
        let weeks = max(1, timeSpan / (7 * 24 * 3600))
        let volume = Double(sessions.count) / weeks
        
        // Overall score (weighted average)
        let overallScore = (consistency * 0.3 + improvement * 0.25 + efficiency * 0.25 + min(volume * 10, 100) * 0.2)
        
        return PerformanceMetrics(
            consistency: consistency,
            improvement: improvement,
            efficiency: efficiency,
            volume: volume,
            overallScore: overallScore
        )
    }
    
    private func calculateProgressData(from sessions: [SessionData]) -> [ProgressDataPoint] {
        guard !sessions.isEmpty else { return [] }
        
        // Group sessions by day and calculate daily averages
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.timestamp)
        }
        
        return grouped.compactMap { date, daySessions in
            let avgRating = daySessions.reduce(0.0) { $0 + Double($1.rating) } / Double(daySessions.count)
            let totalShots = daySessions.reduce(0) { $0 + $1.totalShots }
            let avgSuccessRate = daySessions.reduce(0.0) { $0 + $1.successRate } / Double(daySessions.count)
            
            return ProgressDataPoint(
                date: date,
                rating: avgRating,
                totalShots: totalShots,
                successRate: avgSuccessRate,
                sessionCount: daySessions.count
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateShotTypeDistribution(from sessions: [SessionData]) -> [ShotTypeData] {
        let totalForehand = sessions.reduce(0) { $0 + $1.forehandCount }
        let totalBackhand = sessions.reduce(0) { $0 + $1.backhandCount }
        let totalServes = sessions.reduce(0) { $0 + $1.serveCount }
        let total = totalForehand + totalBackhand + totalServes
        
        guard total > 0 else { return [] }
        
        return [
            ShotTypeData(type: "Forehand", count: totalForehand, percentage: Double(totalForehand) / Double(total)),
            ShotTypeData(type: "Backhand", count: totalBackhand, percentage: Double(totalBackhand) / Double(total)),
            ShotTypeData(type: "Serve", count: totalServes, percentage: Double(totalServes) / Double(total))
        ].filter { $0.count > 0 }
    }
    
    private func calculateWeeklyActivity(from sessions: [SessionData]) -> [WeeklyActivityData] {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        
        let dayGroups = Dictionary(grouping: sessions) { session in
            calendar.component(.weekday, from: session.timestamp)
        }
        
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        
        return (1...7).map { weekday in
            let dayName = weekdays[weekday - 1]
            let daySessions = dayGroups[weekday] ?? []
            let totalShots = daySessions.reduce(0) { $0 + $1.totalShots }
            let sessionCount = daySessions.count
            
            return WeeklyActivityData(
                day: dayName,
                sessionCount: sessionCount,
                totalShots: totalShots
            )
        }
    }
    
    private func calculateSkillProgression(from sessions: [SessionData]) -> [SkillProgressionData] {
        guard sessions.count >= 5 else { return [] }
        
        // Group sessions into chunks of 5 for progression analysis
        let chunkSize = max(1, sessions.count / 10) // Up to 10 data points
        var progressionData: [SkillProgressionData] = []
        
        for i in stride(from: 0, to: sessions.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, sessions.count)
            let chunk = Array(sessions[i..<endIndex])
            
            let avgRating = chunk.reduce(0.0) { $0 + Double($1.rating) } / Double(chunk.count)
            let avgSuccessRate = chunk.reduce(0.0) { $0 + $1.successRate } / Double(chunk.count)
            let totalShots = chunk.reduce(0) { $0 + $1.totalShots }
            
            progressionData.append(SkillProgressionData(
                sessionRange: i + 1,
                rating: avgRating,
                successRate: avgSuccessRate,
                totalShots: totalShots
            ))
        }
        
        return progressionData
    }
    
    private func calculateImprovementTrend(from sessions: [SessionData]) -> Double {
        guard sessions.count >= 4 else { return 0 }
        
        let firstHalf = Array(sessions.prefix(sessions.count / 2))
        let secondHalf = Array(sessions.suffix(sessions.count / 2))
        
        let firstHalfAvg = firstHalf.reduce(0.0) { $0 + Double($1.rating) } / Double(firstHalf.count)
        let secondHalfAvg = secondHalf.reduce(0.0) { $0 + Double($1.rating) } / Double(secondHalf.count)
        
        return (secondHalfAvg - firstHalfAvg) * 20 // Scale to 0-100
    }
    
    private func calculateStreaks(from sessions: [SessionData]) -> (current: Int, longest: Int) {
        guard !sessions.isEmpty else { return (0, 0) }
        
        let calendar = Calendar.current
        let sortedSessions = sessions.sorted { $0.timestamp < $1.timestamp }
        
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 1
        
        // Group by day to find consecutive practice days
        let sessionDays = Set(sortedSessions.map { calendar.startOfDay(for: $0.timestamp) })
        let sortedDays = Array(sessionDays).sorted()
        
        for i in 1..<sortedDays.count {
            let daysDiff = calendar.dateComponents([.day], from: sortedDays[i-1], to: sortedDays[i]).day ?? 0
            
            if daysDiff == 1 {
                tempStreak += 1
            } else {
                longestStreak = max(longestStreak, tempStreak)
                tempStreak = 1
            }
        }
        
        longestStreak = max(longestStreak, tempStreak)
        
        // Calculate current streak from today backwards
        let today = calendar.startOfDay(for: Date())
        if let lastPracticeDay = sortedDays.last {
            let daysSinceLastPractice = calendar.dateComponents([.day], from: lastPracticeDay, to: today).day ?? 0
            
            if daysSinceLastPractice <= 1 {
                // Still in a streak, count backwards
                currentStreak = 1
                for i in stride(from: sortedDays.count - 2, through: 0, by: -1) {
                    let daysDiff = calendar.dateComponents([.day], from: sortedDays[i], to: sortedDays[i + 1]).day ?? 0
                    if daysDiff == 1 {
                        currentStreak += 1
                    } else {
                        break
                    }
                }
            }
        }
        
        return (currentStreak, longestStreak)
    }
    
    // MARK: - Refresh Data
    func refreshStats() {
        isLoading = true
        
        Task {
            // Trigger history refresh which will update our stats
            await historyManager.loadSessions(refresh: true)
            
            await MainActor.run {
                lastUpdate = Date()
                isLoading = false
            }
        }
    }
}

// MARK: - Data Models
struct OverallStatistics {
    let totalSessions: Int
    let totalShots: Int
    let totalPracticeTime: TimeInterval
    let averageRating: Double
    let bestRating: Int
    let averageSessionLength: TimeInterval
    let totalSuccessfulShots: Int
    let overallSuccessRate: Double
    let mostProductiveDay: String
    let currentStreak: Int
    let longestStreak: Int
    
    var totalPracticeTimeFormatted: String {
        let hours = Int(totalPracticeTime) / 3600
        let minutes = Int(totalPracticeTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var averageSessionLengthFormatted: String {
        let minutes = Int(averageSessionLength) / 60
        let seconds = Int(averageSessionLength) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    var overallSuccessRatePercentage: Int {
        Int(overallSuccessRate * 100)
    }
}

struct PerformanceMetrics {
    let consistency: Double
    let improvement: Double
    let efficiency: Double
    let volume: Double
    let overallScore: Double
    
    var consistencyGrade: String {
        switch consistency {
        case 90...: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }
    
    var overallGrade: String {
        switch overallScore {
        case 90...: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }
}

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rating: Double
    let totalShots: Int
    let successRate: Double
    let sessionCount: Int
}

struct ShotTypeData: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let percentage: Double
    
    var color: Color {
        switch type {
        case "Forehand": return .blue
        case "Backhand": return .green
        case "Serve": return .orange
        default: return .gray
        }
    }
}

struct WeeklyActivityData: Identifiable {
    let id = UUID()
    let day: String
    let sessionCount: Int
    let totalShots: Int
}

struct SkillProgressionData: Identifiable {
    let id = UUID()
    let sessionRange: Int
    let rating: Double
    let successRate: Double
    let totalShots: Int
}
