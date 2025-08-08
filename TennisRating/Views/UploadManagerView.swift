import SwiftUI

struct UploadManagerView: View {
    @StateObject private var uploadManager = SessionUploadManager.shared
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Upload Statistics
                uploadStatsSection
                
                // Pending Uploads List
                if !uploadManager.pendingUploads.isEmpty {
                    pendingUploadsSection
                } else {
                    emptyStateView
                }
                
                Spacer()
                
                // Action Buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Upload Manager")
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
    
    // MARK: - Upload Statistics Section
    private var uploadStatsSection: some View {
        VStack(spacing: 15) {
            Text("Upload Statistics")
                .font(.headline)
                .foregroundColor(.secondary)
            
            let stats = uploadManager.uploadStats
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Total",
                    value: "\(stats.totalSessions)",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Uploaded",
                    value: "\(stats.uploadedSessions)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Pending",
                    value: "\(stats.pendingSessions)",
                    icon: "clock.fill",
                    color: .orange
                )
            }
            
            // Success Rate
            if stats.totalSessions > 0 {
                HStack {
                    Text("Success Rate:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(stats.successRatePercentage)%")
                        .bold()
                        .foregroundColor(stats.successRate > 0.8 ? .green : stats.successRate > 0.5 ? .orange : .red)
                }
                
                ProgressView(value: stats.successRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: stats.successRate > 0.8 ? .green : .orange))
            }
            
            // Last Upload
            if let lastUpload = stats.lastUploadDate {
                HStack {
                    Text("Last Upload:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(lastUpload, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    // MARK: - Pending Uploads Section
    private var pendingUploadsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pending Uploads")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(uploadManager.pendingUploads.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(uploadManager.pendingUploads) { sessionData in
                        PendingUploadRow(sessionData: sessionData)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("All Caught Up!")
                .font(.title2)
                .bold()
            
            Text("No pending uploads")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if authManager.useMockData {
                Text("Demo mode - uploads are simulated")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 15) {
            if !uploadManager.pendingUploads.isEmpty {
                Button(action: {
                    Task {
                        await uploadManager.uploadPendingSessions()
                    }
                }) {
                    HStack {
                        if uploadManager.uploadStatus == .uploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(uploadManager.uploadStatus == .uploading ? "Uploading..." : "Upload All")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(uploadManager.uploadStatus == .uploading || !authManager.isAuthenticated)
            }
            
            if uploadManager.uploadStats.totalSessions > 0 {
                Button("Clear All Data") {
                    uploadManager.clearAllData()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            
            if !authManager.isAuthenticated {
                Text("Sign in to upload sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Pending Upload Row
struct PendingUploadRow: View {
    let sessionData: SessionData
    @StateObject private var uploadManager = SessionUploadManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            // Session Icon
            VStack {
                Image(systemName: "figure.tennis")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                // Rating stars (small)
                HStack(spacing: 2) {
                    ForEach(1...sessionData.rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // Session Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(sessionData.totalShots) shots")
                        .font(.subheadline)
                        .bold()
                    
                    Spacer()
                    
                    Text(sessionData.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("\(Int(sessionData.successRate * 100))% success")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDuration(sessionData.sessionDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Shot breakdown
                HStack(spacing: 12) {
                    if sessionData.forehandCount > 0 {
                        Label("\(sessionData.forehandCount)", systemImage: "arrow.right.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if sessionData.backhandCount > 0 {
                        Label("\(sessionData.backhandCount)", systemImage: "arrow.left.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    if sessionData.serveCount > 0 {
                        Label("\(sessionData.serveCount)", systemImage: "arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Upload Action
            Button(action: {
                Task {
                    await uploadManager.uploadSession(sessionData)
                }
            }) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
#Preview {
    UploadManagerView()
}
