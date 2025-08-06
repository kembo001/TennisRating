import Foundation

struct SessionData: Identifiable {
    let id = UUID()
    let totalShots: Int
    let successfulShots: Int
    let timestamp: Date
    let sessionDuration: TimeInterval
    let shotTimings: [TimeInterval]
    
    // Swing type breakdown
    let forehandCount: Int
    let backhandCount: Int
    let serveCount: Int
    
    var successRate: Double {
        guard totalShots > 0 else { return 0 }
        return Double(successfulShots) / Double(totalShots)
    }
    
    var rating: Int {
        let successScore = successRate * 50
        let consistencyScore = consistencyRating * 30
        let volumeScore = min(Double(totalShots) / 50.0, 1.0) * 20
        
        let totalScore = successScore + consistencyScore + volumeScore
        
        switch totalScore {
        case 80...100: return 5
        case 60..<80: return 4
        case 40..<60: return 3
        case 20..<40: return 2
        default: return 1
        }
    }
    
    var averageShotInterval: TimeInterval {
        guard shotTimings.count > 0 else { return 0 }
        return shotTimings.reduce(0, +) / Double(shotTimings.count)
    }
    
    var consistencyRating: Double {
        guard shotTimings.count > 1 else { return 0 }
        
        let avg = averageShotInterval
        let variance = shotTimings.reduce(0) { $0 + pow($1 - avg, 2) } / Double(shotTimings.count)
        let stdDev = sqrt(variance)
        
        let normalizedConsistency = max(0, 1 - (stdDev / avg))
        return normalizedConsistency
    }
    
    var shotsPerMinute: Double {
        guard sessionDuration > 0 else { return 0 }
        return Double(totalShots) / (sessionDuration / 60)
    }
    
    var dominantShot: String {
        if forehandCount > backhandCount && forehandCount > serveCount {
            return "Forehand"
        } else if backhandCount > forehandCount && backhandCount > serveCount {
            return "Backhand"
        } else if serveCount > 0 {
            return "Serve"
        } else {
            return "Mixed"
        }
    }
}
