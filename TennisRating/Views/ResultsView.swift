import SwiftUI

struct ResultsView: View {
    let sessionData: SessionData
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
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
                
                // Stats
                VStack(spacing: 20) {
                    StatRow(title: "Total Shots", value: "\(sessionData.totalShots)")
                    StatRow(title: "Successful Shots", value: "\(sessionData.successfulShots)")
                    StatRow(title: "Success Rate", value: String(format: "%.0f%%", sessionData.successRate * 100))
                    StatRow(title: "Session Time", value: sessionData.timestamp.formatted(date: .omitted, time: .shortened))
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
                
                Spacer()
                
                // Action buttons
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
            .navigationTitle("Practice Results")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [createShareImage()])
        }
    }
    
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
