import SwiftUI
import Foundation
import AVFoundation  // Add this import for AudioServicesPlaySystemSound

// MARK: - Machine Learning Data Structures
struct LabeledSwingData: Codable {
    let label: String // "Forehand", "Backhand", "Serve"
    let poseFrames: [PoseFrameData] // A sequence of pose data
    let sessionId: UUID
    let timestamp: Date
}

struct PoseFrameData: Codable {
    // We capture the key joint locations for the swing
    let wrist: CGPoint?
    let elbow: CGPoint?
    let shoulder: CGPoint?
    let hip: CGPoint?
    let timestamp: TimeInterval
    let confidence: Float // Overall confidence for this frame
}

// MARK: - Calibration Data Storage
class SwingCalibrationData: ObservableObject {
    @Published var forehandPatterns: [SwingPattern] = []
    @Published var backhandPatterns: [SwingPattern] = []
    @Published var servePatterns: [SwingPattern] = []
    @Published var isCalibrating = false
    @Published var calibratingType: SwingType = .forehand
    
    // NEW: Machine Learning Training Data
    @Published var labeledTrainingData: [LabeledSwingData] = []
    private var currentSwingFrames: [PoseFrameData] = []
    private var swingStartTime: Date?
    
    struct SwingPattern: Codable {
        let horizontalChange: CGFloat
        let verticalChange: CGFloat
        let maxSpeed: CGFloat
        let startX: CGFloat
        let startY: CGFloat
        let duration: TimeInterval
        let amplitude: CGFloat
    }
    
    init() {
        loadCalibration()
        loadTrainingData()
    }
    
    // MARK: - Machine Learning Methods
    
    func startRecordingSwing() {
        currentSwingFrames.removeAll()
        swingStartTime = Date()
    }
    
    func addPoseFrame(_ poseFrame: PoseFrame) {
        guard isCalibrating else { return }
        
        let frameData = PoseFrameData(
            wrist: poseFrame.wrist?.location,
            elbow: poseFrame.elbow?.location,
            shoulder: poseFrame.shoulder?.location,
            hip: poseFrame.hip?.location,
            timestamp: poseFrame.timestamp.timeIntervalSince(swingStartTime ?? Date()),
            confidence: calculateFrameConfidence(poseFrame)
        )
        
        currentSwingFrames.append(frameData)
        
        // Limit frames to prevent memory issues (keep last 2 seconds at ~30fps)
        if currentSwingFrames.count > 60 {
            currentSwingFrames.removeFirst()
        }
    }
    
    func completeSwingRecording(forcedType: SwingType) {
        guard currentSwingFrames.count >= 10 else { return } // Need minimum frames
        
        let labeledData = LabeledSwingData(
            label: forcedType.rawValue,
            poseFrames: currentSwingFrames,
            sessionId: UUID(),
            timestamp: Date()
        )
        
        labeledTrainingData.append(labeledData)
        
        // Keep only last 50 labeled swings per type to manage memory
        let typeCount = labeledTrainingData.filter { $0.label == forcedType.rawValue }.count
        if typeCount > 50 {
            if let firstIndex = labeledTrainingData.firstIndex(where: { $0.label == forcedType.rawValue }) {
                labeledTrainingData.remove(at: firstIndex)
            }
        }
        
        saveTrainingData()
        
        // Reset for next swing
        currentSwingFrames.removeAll()
        swingStartTime = nil
    }
    
    private func calculateFrameConfidence(_ poseFrame: PoseFrame) -> Float {
        var totalConfidence: Float = 0
        var count: Float = 0
        
        if let wrist = poseFrame.wrist {
            totalConfidence += wrist.confidence
            count += 1
        }
        if let elbow = poseFrame.elbow {
            totalConfidence += elbow.confidence
            count += 1
        }
        if let shoulder = poseFrame.shoulder {
            totalConfidence += shoulder.confidence
            count += 1
        }
        if let hip = poseFrame.hip {
            totalConfidence += hip.confidence
            count += 1
        }
        
        return count > 0 ? totalConfidence / count : 0
    }
    
    // MARK: - Training Data Persistence
    
    private func saveTrainingData() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(labeledTrainingData)
            UserDefaults.standard.set(data, forKey: "labeledTrainingData")
        } catch {
            print("Failed to save training data: \(error)")
        }
    }
    
    private func loadTrainingData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = UserDefaults.standard.data(forKey: "labeledTrainingData"),
           let loadedData = try? decoder.decode([LabeledSwingData].self, from: data) {
            labeledTrainingData = loadedData
        }
    }
    
    func exportTrainingData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(labeledTrainingData)
    }
    
    func getTrainingDataSummary() -> String {
        let forehandCount = labeledTrainingData.filter { $0.label == "Forehand" }.count
        let backhandCount = labeledTrainingData.filter { $0.label == "Backhand" }.count
        let serveCount = labeledTrainingData.filter { $0.label == "Serve" }.count
        
        return "Training Data - FH: \(forehandCount), BH: \(backhandCount), S: \(serveCount)"
    }
    
    func clearTrainingData() {
        labeledTrainingData.removeAll()
        UserDefaults.standard.removeObject(forKey: "labeledTrainingData")
    }
    
    // MARK: - Original Pattern-Based Methods (kept for backward compatibility)
    
    func addCalibrationSwing(metrics: SwingMetrics, forcedType: SwingType) {
        guard metrics.path.count >= 2 else { return }
        
        let firstPoint = metrics.path.first!
        let lastPoint = metrics.path.last!
        
        let pattern = SwingPattern(
            horizontalChange: (lastPoint.x - firstPoint.x) * 1920,
            verticalChange: (firstPoint.y - lastPoint.y) * 1080,
            maxSpeed: metrics.maxSpeed,
            startX: firstPoint.x,
            startY: firstPoint.y,
            duration: metrics.duration,
            amplitude: metrics.amplitude
        )
        
        switch forcedType {
        case .forehand:
            forehandPatterns.append(pattern)
            if forehandPatterns.count > 10 { forehandPatterns.removeFirst() }
        case .backhand:
            backhandPatterns.append(pattern)
            if backhandPatterns.count > 10 { backhandPatterns.removeFirst() }
        case .serve:
            servePatterns.append(pattern)
            if servePatterns.count > 10 { servePatterns.removeFirst() }
        case .unknown:
            break
        }
        
        saveCalibration()
    }
    
    func classifySwing(metrics: SwingMetrics, startX: CGFloat) -> SwingType {
        guard metrics.path.count >= 2 else { return .unknown }
        
        let firstPoint = metrics.path.first!
        let lastPoint = metrics.path.last!
        
        let horizontalChange = (lastPoint.x - firstPoint.x) * 1920
        let verticalChange = (firstPoint.y - lastPoint.y) * 1080
        
        // Calculate match scores for each type
        let forehandScore = calculateMatchScore(
            patterns: forehandPatterns,
            horizontal: horizontalChange,
            vertical: verticalChange,
            speed: metrics.maxSpeed,
            startX: firstPoint.x,
            startY: firstPoint.y,
            duration: metrics.duration,
            amplitude: metrics.amplitude
        )
        
        let backhandScore = calculateMatchScore(
            patterns: backhandPatterns,
            horizontal: horizontalChange,
            vertical: verticalChange,
            speed: metrics.maxSpeed,
            startX: firstPoint.x,
            startY: firstPoint.y,
            duration: metrics.duration,
            amplitude: metrics.amplitude
        )
        
        let serveScore = calculateMatchScore(
            patterns: servePatterns,
            horizontal: horizontalChange,
            vertical: verticalChange,
            speed: metrics.maxSpeed,
            startX: firstPoint.x,
            startY: firstPoint.y,
            duration: metrics.duration,
            amplitude: metrics.amplitude
        )
        
        // Debug output
        print("Classification Scores - FH: \(forehandScore), BH: \(backhandScore), S: \(serveScore)")
        
        // Return type with highest score
        let maxScore = max(forehandScore, backhandScore, serveScore)
        
        if maxScore < 0.4 { return .unknown }  // Too different from any pattern
        
        if forehandScore == maxScore { return .forehand }
        if backhandScore == maxScore { return .backhand }
        if serveScore == maxScore { return .serve }
        
        return .unknown
    }
    
    private func calculateMatchScore(patterns: [SwingPattern], horizontal: CGFloat, vertical: CGFloat,
                                    speed: CGFloat, startX: CGFloat, startY: CGFloat,
                                    duration: TimeInterval, amplitude: CGFloat) -> Double {
        guard !patterns.isEmpty else { return 0 }
        
        var bestScore = 0.0
        
        for pattern in patterns {
            var score = 0.0
            var weights = 0.0
            
            // Direction matching (MOST IMPORTANT)
            // For forehand/backhand, horizontal direction is critical
            let horizontalMatch: Bool
            if pattern.horizontalChange < -100 && horizontal < -50 {
                // Both are leftward (forehand-like)
                horizontalMatch = true
            } else if pattern.horizontalChange > 100 && horizontal > 50 {
                // Both are rightward (backhand-like)
                horizontalMatch = true
            } else if abs(pattern.horizontalChange) < 100 && abs(horizontal) < 100 {
                // Both are mostly vertical (could be serve)
                horizontalMatch = true
            } else {
                horizontalMatch = false
            }
            
            if horizontalMatch {
                score += 2.0  // Heavy weight for correct direction
                weights += 2.0
            }
            
            // Horizontal movement similarity
            let hDiff = abs(pattern.horizontalChange - horizontal)
            if hDiff < 100 {
                score += 1.0 * (1.0 - hDiff/100.0)
                weights += 1.0
            } else if hDiff < 300 {
                score += 0.5 * (1.0 - hDiff/300.0)
                weights += 0.5
            }
            
            // Vertical movement similarity (important for serves)
            let vDiff = abs(pattern.verticalChange - vertical)
            if abs(pattern.verticalChange) > 150 || abs(vertical) > 150 {
                // This is likely a serve, vertical matters more
                if vDiff < 100 {
                    score += 1.5 * (1.0 - vDiff/100.0)
                    weights += 1.5
                }
            } else {
                // Ground stroke, vertical less important
                if vDiff < 150 {
                    score += 0.3 * (1.0 - vDiff/150.0)
                    weights += 0.3
                }
            }
            
            // Speed similarity (moderate importance)
            let speedRatio = min(speed, pattern.maxSpeed) / max(speed, pattern.maxSpeed)
            score += speedRatio * 0.8
            weights += 0.8
            
            // Starting position (helpful for disambiguation)
            let startXDiff = abs(pattern.startX - startX)
            if startXDiff < 0.15 {
                score += 0.5 * (1.0 - startXDiff/0.15)
                weights += 0.5
            }
            
            // Duration similarity
            let durationRatio = min(duration, pattern.duration) / max(duration, pattern.duration)
            if durationRatio > 0.7 {
                score += 0.4 * durationRatio
                weights += 0.4
            }
            
            // Amplitude similarity
            if amplitude > 50 && pattern.amplitude > 50 {
                let ampRatio = min(amplitude, pattern.amplitude) / max(amplitude, pattern.amplitude)
                score += 0.4 * ampRatio
                weights += 0.4
            }
            
            let normalizedScore = weights > 0 ? score / weights : 0
            bestScore = max(bestScore, normalizedScore)
        }
        
        return bestScore
    }
    
    func saveCalibration() {
        let encoder = JSONEncoder()
        
        if let forehandData = try? encoder.encode(forehandPatterns) {
            UserDefaults.standard.set(forehandData, forKey: "forehandPatterns")
        }
        if let backhandData = try? encoder.encode(backhandPatterns) {
            UserDefaults.standard.set(backhandData, forKey: "backhandPatterns")
        }
        if let serveData = try? encoder.encode(servePatterns) {
            UserDefaults.standard.set(serveData, forKey: "servePatterns")
        }
        
        UserDefaults.standard.set(true, forKey: "hasCalibration")
    }
    
    func loadCalibration() {
        let decoder = JSONDecoder()
        
        if let forehandData = UserDefaults.standard.data(forKey: "forehandPatterns"),
           let patterns = try? decoder.decode([SwingPattern].self, from: forehandData) {
            forehandPatterns = patterns
        }
        
        if let backhandData = UserDefaults.standard.data(forKey: "backhandPatterns"),
           let patterns = try? decoder.decode([SwingPattern].self, from: backhandData) {
            backhandPatterns = patterns
        }
        
        if let serveData = UserDefaults.standard.data(forKey: "servePatterns"),
           let patterns = try? decoder.decode([SwingPattern].self, from: serveData) {
            servePatterns = patterns
        }
    }
    
    func clearCalibration() {
        forehandPatterns.removeAll()
        backhandPatterns.removeAll()
        servePatterns.removeAll()
        
        UserDefaults.standard.removeObject(forKey: "forehandPatterns")
        UserDefaults.standard.removeObject(forKey: "backhandPatterns")
        UserDefaults.standard.removeObject(forKey: "servePatterns")
        UserDefaults.standard.set(false, forKey: "hasCalibration")
    }
    
    func hasCalibration() -> Bool {
        return !forehandPatterns.isEmpty || !backhandPatterns.isEmpty || !servePatterns.isEmpty
    }
    
    var calibrationSummary: String {
        return "FH: \(forehandPatterns.count), BH: \(backhandPatterns.count), S: \(servePatterns.count)"
    }
}

// MARK: - Data Collection Camera View (formerly Calibration Camera View)
struct CalibrationCameraView: View {
    @ObservedObject var calibrationData: SwingCalibrationData
    @Binding var sessionData: SessionData?
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSwingType: SwingType = .forehand
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        ZStack {
            // Camera view
            if viewModel.isSessionRunning {
                GeometryReader { geometry in
                    CameraPreview(session: viewModel.captureSession)
                        .ignoresSafeArea()
                        .overlay(
                            PoseOverlay(
                                poseFrame: viewModel.currentPoseFrame,
                                geometrySize: geometry.size
                            )
                            .allowsHitTesting(false)
                        )
                }
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    )
            }
            
            // Data Collection UI Overlay
            VStack {
                // Top bar with data collection info
                VStack(spacing: 10) {
                    Text("SWING DATA COLLECTOR")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .cornerRadius(10)
                    
                    // Data summary
                    Text(viewModel.getCollectedSwingsSummary())
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                    
                    // Swing type selector
                    Picker("Type", selection: $currentSwingType) {
                        Text("Forehand").tag(SwingType.forehand)
                        Text("Backhand").tag(SwingType.backhand)
                        Text("Serve").tag(SwingType.serve)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Instructions
                VStack(spacing: 10) {
                    Text("Perform a \(currentSwingType.rawValue) swing")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Press 'Record Swing', perform one swing, then press 'Stop'")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Recording status
                    if viewModel.isCapturingSequence {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .scaleEffect(1.5)
                                        .opacity(0.5)
                                        .animation(
                                            Animation.easeInOut(duration: 1)
                                                .repeatForever(autoreverses: true),
                                            value: viewModel.isCapturingSequence
                                        )
                                )
                            Text("RECORDING SWING...")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    
                    if !viewModel.debugInfo.isEmpty {
                        Text(viewModel.debugInfo)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
                .padding()
                
                // Control buttons
                VStack(spacing: 15) {
                    // Primary recording control
                    Button(viewModel.isCapturingSequence ? "Stop Swing" : "Record Swing") {
                        if viewModel.isCapturingSequence {
                            viewModel.stopAndSaveCaptureSequence(label: currentSwingType)
                        } else {
                            viewModel.startCaptureSequence()
                        }
                    }
                    .padding()
                    .frame(width: 200, height: 50)
                    .background(viewModel.isCapturingSequence ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .font(.headline)
                    .cornerRadius(15)
                    .disabled(!viewModel.isSessionRunning)
                    
                    // Secondary controls
                    HStack(spacing: 15) {
                        Button("Export Data") {
                            exportData()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(viewModel.collectedSwings.isEmpty)
                        
                        Button("Clear All") {
                            viewModel.clearAllCollectedSwings()
                        }
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(viewModel.collectedSwings.isEmpty)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            setupDataCollectionMode()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func setupDataCollectionMode() {
        viewModel.checkPermissions()
        
        // Enable debug mode for better feedback
        viewModel.enableDebugMode(true)
        
        // Start the camera session immediately
        if !viewModel.isRecording {
            viewModel.startRecording()
        }
    }
    
    // MARK: - Data Export Function
    private func exportData() {
        guard !viewModel.collectedSwings.isEmpty else {
            viewModel.debugInfo = "No data to export"
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(viewModel.collectedSwings)
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let timestamp = DateFormatter().string(from: Date())
            let filename = "swing_data_\(timestamp.replacingOccurrences(of: " ", with: "_")).json"
            let fileURL = documents.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            
            print("Successfully exported to \(fileURL)")
            viewModel.debugInfo = "✅ Exported \(viewModel.collectedSwings.count) swings to Files app!"
            
            // Prepare for sharing
            exportURL = fileURL
            showingShareSheet = true
            
            // Also print summary to console for development
            printDataSummary()
            
        } catch {
            print("Error exporting data: \(error)")
            viewModel.debugInfo = "❌ Export failed: \(error.localizedDescription)"
        }
    }
    
    private func printDataSummary() {
        print("\n=== SWING DATA EXPORT SUMMARY ===")
        print("Total swings collected: \(viewModel.collectedSwings.count)")
        
        let forehandCount = viewModel.collectedSwings.filter { $0.label == "Forehand" }.count
        let backhandCount = viewModel.collectedSwings.filter { $0.label == "Backhand" }.count
        let serveCount = viewModel.collectedSwings.filter { $0.label == "Serve" }.count
        
        print("Breakdown:")
        print("  Forehand: \(forehandCount)")
        print("  Backhand: \(backhandCount)")
        print("  Serve: \(serveCount)")
        
        if let firstSwing = viewModel.collectedSwings.first {
            print("Sample swing info:")
            print("  Frames per swing: \(firstSwing.poseFrames.count)")
            print("  Duration: \(firstSwing.poseFrames.last?.timestamp ?? 0) seconds")
        }
        print("================================\n")
    }
}

