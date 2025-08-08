import Foundation

struct SessionData: Identifiable, Codable {
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
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, totalShots, successfulShots, timestamp, sessionDuration, shotTimings
        case forehandCount, backhandCount, serveCount
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(totalShots, forKey: .totalShots)
        try container.encode(successfulShots, forKey: .successfulShots)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionDuration, forKey: .sessionDuration)
        try container.encode(shotTimings, forKey: .shotTimings)
        try container.encode(forehandCount, forKey: .forehandCount)
        try container.encode(backhandCount, forKey: .backhandCount)
        try container.encode(serveCount, forKey: .serveCount)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let totalShots = try container.decode(Int.self, forKey: .totalShots)
        let successfulShots = try container.decode(Int.self, forKey: .successfulShots)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let sessionDuration = try container.decode(TimeInterval.self, forKey: .sessionDuration)
        let shotTimings = try container.decode([TimeInterval].self, forKey: .shotTimings)
        let forehandCount = try container.decode(Int.self, forKey: .forehandCount)
        let backhandCount = try container.decode(Int.self, forKey: .backhandCount)
        let serveCount = try container.decode(Int.self, forKey: .serveCount)
        
        self.init(
            totalShots: totalShots,
            successfulShots: successfulShots,
            timestamp: timestamp,
            sessionDuration: sessionDuration,
            shotTimings: shotTimings,
            forehandCount: forehandCount,
            backhandCount: backhandCount,
            serveCount: serveCount
        )
    }
    
    // MARK: - Regular Initializer (for your existing code)
    init(
        totalShots: Int,
        successfulShots: Int,
        timestamp: Date,
        sessionDuration: TimeInterval,
        shotTimings: [TimeInterval],
        forehandCount: Int,
        backhandCount: Int,
        serveCount: Int
    ) {
        self.totalShots = totalShots
        self.successfulShots = successfulShots
        self.timestamp = timestamp
        self.sessionDuration = sessionDuration
        self.shotTimings = shotTimings
        self.forehandCount = forehandCount
        self.backhandCount = backhandCount
        self.serveCount = serveCount
    }
}
