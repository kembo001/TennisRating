import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var historyManager = SessionHistoryManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var showingFilters = false
    @State private var selectedSession: SessionData?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistics Header
                if !historyManager.filteredSessions.isEmpty {
                    statisticsHeader
                        .padding()
                        .background(Color(.systemGray6))
                }
                
                // Sessions List
                if historyManager.isLoading {
                    loadingView
                } else if historyManager.filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionsListView
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Filter button
                        Button(action: {
                            showingFilters = true
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        
                        // Refresh button
                        Button(action: {
                            historyManager.refresh()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(historyManager.isLoading)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FiltersView()
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(sessionData: session)
            }
            .task {
                await historyManager.loadSessions()
            }
            .refreshable {
                await historyManager.loadSessions(refresh: true)
            }
        }
    }
    
    // MARK: - Statistics Header
    private var statisticsHeader: some View {
        let stats = historyManager.sessionStats
        
        return VStack(spacing: 15) {
            // Period selector
          if #available(iOS 17.0, *) {
            Picker("Period", selection: $historyManager.selectedPeriod) {
              ForEach(SessionHistoryManager.TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
              }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: historyManager.selectedPeriod) { _, _ in
              historyManager.updateSortingAndFiltering()
            }
          } else {
            // Fallback on earlier versions
          }
            
            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                StatCardCompact(
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "list.bullet",
                    color: .blue
                )
                
                StatCardCompact(
                    title: "Avg Rating",
                    value: stats.averageRatingFormatted,
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatCardCompact(
                    title: "Total Shots",
                    value: "\(stats.totalShots)",
                    icon: "target",
                    color: .green
                )
                
                StatCardCompact(
                    title: "Success Rate",
                    value: "\(stats.averageSuccessRatePercentage)%",
                    icon: "checkmark.circle",
                    color: .orange
                )
                
                StatCardCompact(
                    title: "Time Played",
                    value: stats.totalDurationFormatted,
                    icon: "clock",
                    color: .purple
                )
                
                StatCardCompact(
                    title: "Progress",
                    value: stats.improvementTrendFormatted,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .pink
                )
            }
        }
    }
    
    // MARK: - Sessions List
    private var sessionsListView: some View {
        List {
            ForEach(historyManager.filteredSessions) { session in
                SessionRowView(session: session)
                    .onTapGesture {
                        selectedSession = session
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text("Loading your sessions...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.tennis")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Practice Sessions")
                .font(.title2)
                .bold()
            
            Text("Start practicing to see your session history here!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !authManager.isAuthenticated {
                VStack(spacing: 10) {
                    Text("Sign in to sync sessions across devices")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
            }
            
            if authManager.useMockData && authManager.isAuthenticated {
                VStack(spacing: 10) {
                    Text("Demo Mode")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                    
                    Text("Complete practice sessions to see them here")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: SessionData
    
    var body: some View {
        HStack(spacing: 15) {
            // Rating and date
            VStack(spacing: 5) {
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= session.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                // Date
                Text(session.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            // Session details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(session.totalShots) shots")
                        .font(.headline)
                        .bold()
                    
                    Spacer()
                    
                    Text("\(Int(session.successRate * 100))% success")
                        .font(.subheadline)
                        .foregroundColor(successRateColor(session.successRate))
                }
                
                HStack {
                    Text(formatDuration(session.sessionDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(session.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Shot breakdown
                if session.totalShots > 0 {
                    HStack(spacing: 12) {
                        if session.forehandCount > 0 {
                            Label("\(session.forehandCount)", systemImage: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if session.backhandCount > 0 {
                            Label("\(session.backhandCount)", systemImage: "arrow.left.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        
                        if session.serveCount > 0 {
                            Label("\(session.serveCount)", systemImage: "arrow.up.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    private func successRateColor(_ rate: Double) -> Color {
        if rate >= 0.8 { return .green }
        if rate >= 0.6 { return .orange }
        return .red
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Compact Stat Card
struct StatCardCompact: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Filters View
struct FiltersView: View {
    @StateObject private var historyManager = SessionHistoryManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Time Period
                VStack(alignment: .leading, spacing: 15) {
                    Text("Time Period")
                        .font(.headline)
                    
                    Picker("Period", selection: $historyManager.selectedPeriod) {
                        ForEach(SessionHistoryManager.TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                
                // Sort Options
                VStack(alignment: .leading, spacing: 15) {
                    Text("Sort By")
                        .font(.headline)
                    
                    Picker("Sort", selection: $historyManager.sortBy) {
                        ForEach(SessionHistoryManager.SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    
                    HStack {
                        Text("Order:")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("Order", selection: $historyManager.sortAscending) {
                            Text("Newest First").tag(false)
                            Text("Oldest First").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        historyManager.selectedPeriod = .all
                        historyManager.sortBy = .date
                        historyManager.sortAscending = false
                        historyManager.updateSortingAndFiltering()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        historyManager.updateSortingAndFiltering()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    let sessionData: SessionData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Header with rating
                    VStack(spacing: 15) {
                        Text(sessionData.timestamp.formatted(date: .complete, time: .shortened))
                            .font(.title2)
                            .bold()
                        
                        HStack(spacing: 5) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= sessionData.rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.top)
                    
                    // Detailed stats
                    VStack(spacing: 20) {
                        StatRow(title: "Total Shots", value: "\(sessionData.totalShots)")
                        StatRow(title: "Successful Shots", value: "\(sessionData.successfulShots)")
                        StatRow(title: "Success Rate", value: String(format: "%.0f%%", sessionData.successRate * 100))
                        StatRow(title: "Duration", value: formatDuration(sessionData.sessionDuration))
                        StatRow(title: "Shots per Minute", value: String(format: "%.1f", sessionData.shotsPerMinute))
                        StatRow(title: "Consistency Rating", value: String(format: "%.0f%%", sessionData.consistencyRating * 100))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // Shot breakdown
                    if sessionData.totalShots > 0 {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Shot Breakdown")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Label("Forehands", systemImage: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text("\(sessionData.forehandCount)")
                                        .bold()
                                }
                                
                                HStack {
                                    Label("Backhands", systemImage: "arrow.left.circle.fill")
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text("\(sessionData.backhandCount)")
                                        .bold()
                                }
                                
                                HStack {
                                    Label("Serves", systemImage: "arrow.up.circle.fill")
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text("\(sessionData.serveCount)")
                                        .bold()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(15)
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    SessionHistoryView()
}
