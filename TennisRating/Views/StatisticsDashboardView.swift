import SwiftUI

struct StatisticsDashboardView: View {
    @StateObject private var statsManager = StatisticsManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time frame selector
                timeFrameSelector
                
                if statsManager.overallStats.totalSessions == 0 {
                    emptyStateView
                } else {
                    // Dashboard content
                    TabView(selection: $selectedTab) {
                        overviewTab
                            .tag(0)
                        
                        performanceTab
                            .tag(1)
                        
                        progressTab
                            .tag(2)
                        
                        activityTab
                            .tag(3)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Custom tab indicators
                    tabIndicators
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        statsManager.refreshStats()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(statsManager.isLoading ? 360 : 0))
                            .animation(statsManager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: statsManager.isLoading)
                    }
                    .disabled(statsManager.isLoading)
                }
            }
        }
    }
    
    // MARK: - Time Frame Selector
    private var timeFrameSelector: some View {
        Picker("Time Frame", selection: $statsManager.selectedTimeFrame) {
            ForEach(StatisticsManager.TimeFrame.allCases, id: \.self) { timeFrame in
                Text(timeFrame.rawValue).tag(timeFrame)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Overview Tab
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Hero stats
                heroStatsSection
                
                // Performance metrics
                performanceMetricsSection
                
                // Quick insights
                quickInsightsSection
            }
            .padding()
        }
    }
    
    // MARK: - Performance Tab
    private var performanceTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Performance radar chart
                performanceRadarSection
                
                // Shot type distribution
                shotTypeDistributionSection
                
                // Detailed metrics
                detailedMetricsSection
            }
            .padding()
        }
    }
    
    // MARK: - Progress Tab
    private var progressTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Progress line chart
                progressChartSection
                
                // Skill progression
                skillProgressionSection
                
                // Streaks and consistency
                streaksSection
            }
            .padding()
        }
    }
    
    // MARK: - Activity Tab
    private var activityTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Weekly activity chart
                weeklyActivitySection
                
                // Practice patterns
                practicePatternsSection
                
                // Goals and achievements
                achievementsSection
            }
            .padding()
        }
    }
    
    // MARK: - Hero Stats Section
    private var heroStatsSection: some View {
        let stats = statsManager.overallStats
        
        return VStack(spacing: 15) {
            Text("Overview")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                HeroStatCard(
                    title: "Total Sessions",
                    value: "\(stats.totalSessions)",
                    subtitle: stats.totalPracticeTimeFormatted,
                    icon: "figure.tennis",
                    color: Color.blue
                )
                
                HeroStatCard(
                    title: "Total Shots",
                    value: "\(stats.totalShots)",
                    subtitle: "\(stats.overallSuccessRatePercentage)% success",
                    icon: "target",
                    color: Color.green
                )
                
                HeroStatCard(
                    title: "Average Rating",
                    value: String(format: "%.1f", stats.averageRating),
                    subtitle: "Best: \(stats.bestRating) ⭐",
                    icon: "star.fill",
                    color: Color.yellow
                )
                
                HeroStatCard(
                    title: "Current Streak",
                    value: "\(stats.currentStreak)",
                    subtitle: "Longest: \(stats.longestStreak) days",
                    icon: "flame.fill",
                    color: Color.orange
                )
            }
        }
    }
    
    // MARK: - Performance Metrics Section
    private var performanceMetricsSection: some View {
        let metrics = statsManager.performanceMetrics
        
        return VStack(spacing: 15) {
            Text("Performance Grade")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack {
                    Text(metrics.overallGrade)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(gradeColor(metrics.overallGrade))
                    
                    Text("Overall Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(gradeColor(metrics.overallGrade).opacity(0.1))
                .cornerRadius(15)
                
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(title: "Consistency", value: Int(metrics.consistency), color: Color.blue)
                    MetricRow(title: "Improvement", value: Int(metrics.improvement), color: Color.green)
                    MetricRow(title: "Efficiency", value: Int(metrics.efficiency * 10), color: Color.orange)
                    MetricRow(title: "Volume", value: Int(metrics.volume * 10), color: Color.purple)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Quick Insights Section
    private var quickInsightsSection: some View {
        let stats = statsManager.overallStats
        
        return VStack(spacing: 15) {
            Text("Insights")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                InsightCard(
                    icon: "calendar",
                    title: "Most Active Day",
                    value: stats.mostProductiveDay,
                    color: Color.blue
                )
                
                InsightCard(
                    icon: "clock",
                    title: "Average Session",
                    value: stats.averageSessionLengthFormatted,
                    color: Color.green
                )
                
                InsightCard(
                    icon: "target",
                    title: "Success Rate",
                    value: "\(stats.overallSuccessRatePercentage)%",
                    color: Color.orange
                )
            }
        }
    }
    
    // MARK: - Shot Type Distribution Section
    private var shotTypeDistributionSection: some View {
        let shotData = statsManager.shotTypeDistribution
        
        return VStack(spacing: 15) {
            Text("Shot Distribution")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if shotData.isEmpty {
                Text("No shot data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                HStack {
                    // Simple circle visualization
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        VStack {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(shotData.reduce(0) { $0 + $1.count })")
                                .font(.title2)
                                .bold()
                            
                            Text("Shots")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(shotData) { data in
                            HStack {
                                Circle()
                                    .fill(data.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(data.type)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("\(data.count)")
                                        .font(.subheadline)
                                        .bold()
                                    
                                    Text("\(Int(data.percentage * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
            }
        }
    }
    
    // MARK: - Progress Chart Section (iOS 15 compatible)
    private var progressChartSection: some View {
        let progressData = statsManager.progressData
        
        return VStack(spacing: 15) {
            Text("Rating Progress")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if progressData.isEmpty {
                Text("Complete more sessions to see progress")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                // Simple progress visualization for iOS 15
                VStack(spacing: 12) {
                    HStack {
                        Text("Rating Trend")
                            .font(.headline)
                        Spacer()
                        if let first = progressData.first, let last = progressData.last {
                            let trend = last.rating - first.rating
                            HStack {
                                Image(systemName: trend > 0 ? "arrow.up" : trend < 0 ? "arrow.down" : "minus")
                                    .foregroundColor(trend > 0 ? .green : trend < 0 ? .red : .gray)
                                Text(String(format: "%.1f", trend))
                                    .bold()
                                    .foregroundColor(trend > 0 ? .green : trend < 0 ? .red : .gray)
                            }
                        }
                    }
                    
                    // Progress dots visualization
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(Array(progressData.enumerated()), id: \.element.id) { index, dataPoint in
                                VStack {
                                    Circle()
                                        .fill(ratingColor(dataPoint.rating))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Text("\(Int(dataPoint.rating))")
                                                .font(.caption2)
                                                .bold()
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(dataPoint.date, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Recent sessions summary
                    if let lastFive = Array(progressData.suffix(5)).isEmpty ? nil : Array(progressData.suffix(5)) {
                        HStack {
                            Text("Last 5 Sessions:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                ForEach(lastFive, id: \.id) { session in
                                    Text("⭐")
                                        .font(.caption2)
                                        .foregroundColor(ratingColor(session.rating))
                                }
                            }
                            
                            Spacer()
                            
                            let avgRating = lastFive.reduce(0) { $0 + $1.rating } / Double(lastFive.count)
                            Text("Avg: \(String(format: "%.1f", avgRating))")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
            }
        }
    }
    
    // MARK: - Weekly Activity Section (iOS 15 compatible)
    private var weeklyActivitySection: some View {
        let activityData = statsManager.weeklyActivity
        
        return VStack(spacing: 15) {
            Text("Weekly Activity")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Simple bar visualization
            VStack(spacing: 12) {
                HStack {
                    ForEach(activityData) { data in
                        VStack {
                            Text(String(data.day.prefix(3)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Rectangle()
                                .fill(data.sessionCount > 0 ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 25, height: max(CGFloat(data.sessionCount) * 30, 5))
                                .cornerRadius(4)
                            
                            Text("\(data.sessionCount)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(data.sessionCount > 0 ? .blue : .gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                HStack {
                    Text("Sessions per day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let maxSessions = activityData.map { $0.sessionCount }.max() ?? 0
                    Text("Peak: \(maxSessions)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
    }
    
    // MARK: - Performance Radar Section
    private var performanceRadarSection: some View {
        let metrics = statsManager.performanceMetrics
        
        return VStack(spacing: 15) {
            Text("Performance Breakdown")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                PerformanceBar(title: "Consistency", value: metrics.consistency, color: Color.blue)
                PerformanceBar(title: "Improvement", value: metrics.improvement + 50, color: Color.green)
                PerformanceBar(title: "Efficiency", value: metrics.efficiency * 10, color: Color.orange)
                PerformanceBar(title: "Volume", value: min(metrics.volume * 20, 100), color: Color.purple)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
    }
    
    // MARK: - Skill Progression Section
    private var skillProgressionSection: some View {
        let skillData = statsManager.skillProgression
        
        return VStack(spacing: 15) {
            Text("Skill Progression")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if skillData.isEmpty {
                Text("Complete more sessions to see skill progression")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("Success Rate Over Time")
                            .font(.headline)
                        Spacer()
                        if let first = skillData.first, let last = skillData.last {
                            let improvement = (last.successRate - first.successRate) * 100
                            HStack {
                                Image(systemName: improvement > 0 ? "arrow.up" : improvement < 0 ? "arrow.down" : "minus")
                                    .foregroundColor(improvement > 0 ? .green : improvement < 0 ? .red : .gray)
                                Text("\(Int(improvement))%")
                                    .bold()
                                    .foregroundColor(improvement > 0 ? .green : improvement < 0 ? .red : .gray)
                            }
                        }
                    }
                    
                    // Simple progression dots
                    HStack {
                        ForEach(Array(skillData.enumerated()), id: \.element.id) { index, data in
                            VStack {
                                Circle()
                                    .fill(Color.green.opacity(data.successRate))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("\(Int(data.successRate * 100))")
                                            .font(.caption2)
                                            .bold()
                                            .foregroundColor(.white)
                                    )
                                
                                Text("\(data.sessionRange)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
            }
        }
    }
    
    // MARK: - Streaks Section
    private var streaksSection: some View {
        let stats = statsManager.overallStats
        
        return VStack(spacing: 15) {
            Text("Streaks & Consistency")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                StreakCard(
                    title: "Current Streak",
                    value: "\(stats.currentStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    color: stats.currentStreak > 0 ? Color.orange : Color.gray
                )
                
                StreakCard(
                    title: "Best Streak",
                    value: "\(stats.longestStreak)",
                    subtitle: "days",
                    icon: "trophy.fill",
                    color: Color.yellow
                )
            }
        }
    }
    
    // MARK: - Practice Patterns Section
    private var practicePatternsSection: some View {
        let stats = statsManager.overallStats
        
        return VStack(spacing: 15) {
            Text("Practice Patterns")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                PatternCard(
                    icon: "calendar",
                    title: "Most Active Day",
                    value: stats.mostProductiveDay,
                    description: "Your most frequent practice day"
                )
                
                PatternCard(
                    icon: "clock",
                    title: "Average Session",
                    value: stats.averageSessionLengthFormatted,
                    description: "Typical practice duration"
                )
                
                PatternCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Total Practice Time",
                    value: stats.totalPracticeTimeFormatted,
                    description: "Time invested in improvement"
                )
            }
        }
    }
    
    // MARK: - Achievements Section
    private var achievementsSection: some View {
        let stats = statsManager.overallStats
        
        return VStack(spacing: 15) {
            Text("Achievements")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AchievementBadge(
                    title: "Sessions Master",
                    description: "\(stats.totalSessions) sessions completed",
                    icon: "figure.tennis",
                    isUnlocked: stats.totalSessions >= 10,
                    color: Color.blue
                )
                
                AchievementBadge(
                    title: "Sharpshooter",
                    description: "\(stats.totalShots) shots taken",
                    icon: "target",
                    isUnlocked: stats.totalShots >= 500,
                    color: Color.green
                )
                
                AchievementBadge(
                    title: "Perfectionist",
                    description: "5-star rating achieved",
                    icon: "star.fill",
                    isUnlocked: stats.bestRating == 5,
                    color: Color.yellow
                )
                
                AchievementBadge(
                    title: "Streak Legend",
                    description: "7+ day streak",
                    icon: "flame.fill",
                    isUnlocked: stats.longestStreak >= 7,
                    color: Color.orange
                )
            }
        }
    }
    
    // MARK: - Detailed Metrics Section
    private var detailedMetricsSection: some View {
        let stats = statsManager.overallStats
        
        return VStack(spacing: 15) {
            Text("Detailed Metrics")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                DetailedMetricRow(title: "Total Sessions", value: "\(stats.totalSessions)")
                DetailedMetricRow(title: "Total Shots", value: "\(stats.totalShots)")
                DetailedMetricRow(title: "Successful Shots", value: "\(stats.totalSuccessfulShots)")
                DetailedMetricRow(title: "Success Rate", value: "\(stats.overallSuccessRatePercentage)%")
                DetailedMetricRow(title: "Average Rating", value: String(format: "%.1f ⭐", stats.averageRating))
                DetailedMetricRow(title: "Best Rating", value: "\(stats.bestRating) ⭐")
                DetailedMetricRow(title: "Total Practice Time", value: stats.totalPracticeTimeFormatted)
                DetailedMetricRow(title: "Average Session", value: stats.averageSessionLengthFormatted)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
    }
    
    // MARK: - Tab Indicators
    private var tabIndicators: some View {
        HStack(spacing: 20) {
            TabIndicator(title: "Overview", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabIndicator(title: "Performance", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabIndicator(title: "Progress", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
            
            TabIndicator(title: "Activity", isSelected: selectedTab == 3) {
                selectedTab = 3
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Statistics Yet")
                .font(.title2)
                .bold()
            
            Text("Complete practice sessions to see detailed analytics and insights about your tennis progress!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if authManager.useMockData {
                VStack(spacing: 8) {
                    Text("Demo Mode")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                    
                    Text("Statistics will appear after practice sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A+", "A": return Color.green
        case "B": return Color.blue
        case "C": return Color.orange
        default: return Color.red
        }
    }
    
    private func ratingColor(_ rating: Double) -> Color {
        switch rating {
        case 4.5...5: return Color.green
        case 3.5..<4.5: return Color.blue
        case 2.5..<3.5: return Color.orange
        default: return Color.red
        }
    }
}

// MARK: - Supporting Views

struct HeroStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .bold()
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(15)
    }
}

struct MetricRow: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(value)")
                .font(.caption)
                .bold()
                .foregroundColor(color)
        }
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .bold()
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PerformanceBar: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(value))")
                    .font(.caption)
                    .bold()
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / 100, 1), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct StreakCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(15)
    }
}

struct PatternCard: View {
    let icon: String
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                
                Text(value)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.blue)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AchievementBadge: View {
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isUnlocked ? color : .gray)
            
            Text(title)
                .font(.caption)
                .bold()
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background((isUnlocked ? color : Color.gray).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? color : Color.gray, lineWidth: isUnlocked ? 2 : 1)
        )
        .opacity(isUnlocked ? 1 : 0.6)
    }
}

struct DetailedMetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .bold()
        }
        .font(.subheadline)
    }
}

struct TabIndicator: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
        }
    }
}

#Preview {
    StatisticsDashboardView()
}
