import Foundation

struct SessionData: Identifiable {
    let id = UUID()
    let totalShots: Int
    let successfulShots: Int
    let timestamp: Date
    
    var successRate: Double {
        guard totalShots > 0 else { return 0 }
        return Double(successfulShots) / Double(totalShots)
    }
    
    var rating: Int {
        switch successRate {
        case 0.8...1.0: return 5
        case 0.6..<0.8: return 4
        case 0.4..<0.6: return 3
        case 0.2..<0.4: return 2
        default: return 1
        }
    }
}
