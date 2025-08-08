import SwiftUI

struct ResultsView: View {
    let sessionData: SessionData
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @StateObject private var uploadManager = SessionUploadManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Rating stars
                VStack(spacing: 10) {
                    Text("Your Rating")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 5) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= sessionData.rating ? "star.fill" : "star")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.top, 20)
                
                // Upload Status Section
                uploadStatusSection
                
                // Stats
                VStack(spacing: 20) {
                    StatRow(title: "Total Shots", value: "\(sessionData.totalShots)")
                    StatRow(title: "Successful Shots", value: "\(sessionData.successfulShots)")
                    StatRow(title: "Success Rate", value: String(format: "%.0f%%", sessionData.successRate * 100))
                    StatRow(title: "Duration", value: formatDuration(sessionData.sessionDuration))
                    
                    // Swing type breakdown
                    if sessionData.totalShots > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Shot Breakdown")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Label("\(sessionData.forehandCount)", systemImage: "arrow.right.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Forehands")
                                Spacer()
                            }
                            
                            HStack {
                                Label("\(sessionData.backhandCount)", systemImage: "arrow.left.circle.fill")
                                    .foregroundColor(.green)
                                Text("Backhands")
                                Spacer()
                            }
                            
                            HStack {
                                Label("\(sessionData.serveCount)", systemImage: "arrow.up.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Serves")
                                Spacer()
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Feedback message
                Text(getFeedbackMessage())
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Practice tips based on performance
                VStack(alignment: .leading, spacing: 10) {
                    Text("Practice Tips:")
                        .font(.headline)
                    
                    ForEach(getPracticeTips(), id: \.self) { tip in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(tip)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Practice Results")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [createShareImage()])
        }
        .alert("Upload Status", isPresented: $uploadManager.showUploadAlert) {
            Button("OK") {
                uploadManager.showUploadAlert = false
            }
            
            if case .failed = uploadManager.uploadStatus {
                Button("Retry") {
                    Task {
                        await uploadManager.uploadSession(sessionData)
                    }
                }
            }
        } message: {
            Text(uploadAlertMessage)
        }
        .onAppear {
            // Auto-upload if user is logged in and it's a good session
            if authManager.isAuthenticated && sessionData.totalShots >= 5 {
                uploadManager.autoUploadSession(sessionData)
            }
        }
    }
    
    // MARK: - Upload Status Section
    @ViewBuilder
    private var uploadStatusSection: some View {
        if authManager.isAuthenticated {
            VStack(spacing: 10) {
                switch uploadManager.uploadStatus {
                case .idle:
                    EmptyView()
                    
                case .uploading:
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        
                        VStack(alignment: .leading) {
                            Text("Uploading Session...")
                                .font(.caption)
                                .bold()
                            
                            ProgressView(value: uploadManager.uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 150)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                case .success(let sessionId):
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Session Uploaded!")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                            
                            if authManager.useMockData {
                                Text("ID: \(sessionId)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                case .failed(let error):
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Upload Failed")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.orange)
                            
                            Text("Saved for retry")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Retry") {
                            Task {
                                await uploadManager.uploadSession(sessionData)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    
                case .retry:
                    EmptyView()
                }
            }
            .padding(.horizontal)
        } else {
            // Show login prompt for better uploads
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.blue)
                    
                    Text("Sign in to save your progress")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text("Sessions will be uploaded automatically")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                Button(action: {
                    showShareSheet = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Manual upload button (if not auto-uploaded or failed)
                if authManager.isAuthenticated {
                    Button(action: {
                        Task {
                            await uploadManager.uploadSession(sessionData)
                        }
                    }) {
                        Label(uploadButtonText, systemImage: uploadButtonIcon)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(uploadButtonColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(uploadManager.uploadStatus == .uploading)
                }
            }
            
            Button(action: {
                dismiss()
            }) {
                Label("Done", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Upload Button Properties
    private var uploadButtonText: String {
        switch uploadManager.uploadStatus {
        case .uploading:
            return "Uploading..."
        case .success:
            return "Re-upload"
        case .failed:
            return "Retry Upload"
        default:
            return "Upload Session"
        }
    }
    
    private var uploadButtonIcon: String {
        switch uploadManager.uploadStatus {
        case .uploading:
            return "arrow.up.circle"
        case .success:
            return "arrow.clockwise"
        case .failed:
            return "exclamationmark.arrow.triangle.2.circlepath"
        default:
            return "icloud.and.arrow.up"
        }
    }
    
    private var uploadButtonColor: Color {
        switch uploadManager.uploadStatus {
        case .success:
            return .gray
        case .failed:
            return .orange
        default:
            return .blue
        }
    }
    
    // MARK: - Upload Alert Message
    private var uploadAlertMessage: String {
        switch uploadManager.uploadStatus {
        case .success(let sessionId):
            if authManager.useMockData {
                return "Session uploaded successfully!\nDemo ID: \(sessionId)"
            } else {
                return "Session uploaded successfully!"
            }
        case .failed(let error):
            return "Upload failed: \(error)\n\nYour session has been saved and will be retried automatically."
        default:
            return ""
        }
    }
    
    // MARK: - Existing Methods (unchanged)
    func getFeedbackMessage() -> String {
        switch sessionData.rating {
        case 5:
            return "Excellent! You're crushing it! 🎾"
        case 4:
            return "Great job! Keep up the consistency!"
        case 3:
            return "Good practice! Room for improvement."
        case 2:
            return "Keep practicing, you'll get there!"
        default:
            return "Every champion started somewhere. Keep going!"
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func getPracticeTips() -> [String] {
        var tips: [String] = []
        
        // Tips based on success rate
        if sessionData.successRate < 0.5 {
            tips.append("Focus on control over power - aim for consistency")
        }
        
        // Tips based on volume
        if sessionData.totalShots < 20 {
            tips.append("Try longer practice sessions (aim for 50+ shots)")
        }
        
        // Tips based on consistency
        if sessionData.consistencyRating < 0.7 {
            tips.append("Work on rhythm - try to maintain steady shot intervals")
        }
        
        // Tips based on shots per minute
        if sessionData.shotsPerMinute < 5 {
            tips.append("Increase practice intensity with quicker ball feeds")
        }
        
        if tips.isEmpty {
            tips.append("Great session! Try adding more variety to your shots")
            tips.append("Challenge yourself with different target zones")
        }
        
        return tips
    }
    
    func createShareImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500))
        
        return renderer.image { context in
            // Background
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 400, height: 500)))
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            "Tennis Practice Results".draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            // Rating stars
            let starY: CGFloat = 120
            for i in 0..<5 {
                let starX = CGFloat(80 + i * 50)
                let starImage = UIImage(systemName: i < sessionData.rating ? "star.fill" : "star")
                starImage?.withTintColor(.systemYellow).draw(at: CGPoint(x: starX, y: starY))
            }
            
            // Stats
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ]
            
            let stats = [
                "Total Shots: \(sessionData.totalShots)",
                "Successful: \(sessionData.successfulShots)",
                "Success Rate: \(Int(sessionData.successRate * 100))%"
            ]
            
            for (index, stat) in stats.enumerated() {
                stat.draw(at: CGPoint(x: 50, y: 220 + CGFloat(index * 40)), withAttributes: statsAttributes)
            }
            
            // Date
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            sessionData.timestamp.formatted().draw(at: CGPoint(x: 50, y: 400), withAttributes: dateAttributes)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
