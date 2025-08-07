import SwiftUI
import Foundation
import AVFoundation  // Add this import for AudioServicesPlaySystemSound

// MARK: - Calibration Data Storage
class SwingCalibrationData: ObservableObject {
    @Published var forehandPatterns: [SwingPattern] = []
    @Published var backhandPatterns: [SwingPattern] = []
    @Published var servePatterns: [SwingPattern] = []
    @Published var isCalibrating = false
    @Published var calibratingType: SwingType = .forehand
    
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
    }
    
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
            
            // Horizontal movement similarity (most important for FH/BH)
            let hDiff = abs(pattern.horizontalChange - horizontal)
            if hDiff < 50 {
                score += 1.0
            } else if hDiff < 100 {
                score += 0.7
            } else if hDiff < 200 {
                score += 0.3
            }
            
            // Vertical movement similarity (important for serves)
            let vDiff = abs(pattern.verticalChange - vertical)
            if vDiff < 50 {
                score += 0.8
            } else if vDiff < 100 {
                score += 0.5
            } else if vDiff < 200 {
                score += 0.2
            }
            
            // Speed similarity
            let speedRatio = min(speed, pattern.maxSpeed) / max(speed, pattern.maxSpeed)
            score += speedRatio * 0.6
            
            // Starting position similarity
            let startDiff = abs(pattern.startX - startX)
            if startDiff < 0.1 {
                score += 0.4
            } else if startDiff < 0.2 {
                score += 0.2
            }
            
            // Duration similarity
            let durationRatio = min(duration, pattern.duration) / max(duration, pattern.duration)
            score += durationRatio * 0.3
            
            // Amplitude similarity
            let ampRatio = min(amplitude, pattern.amplitude) / max(amplitude, pattern.amplitude)
            score += ampRatio * 0.3
            
            bestScore = max(bestScore, score / 3.4)  // Normalize to 0-1
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

// MARK: - Calibration Camera View
struct CalibrationCameraView: View {
    @ObservedObject var calibrationData: SwingCalibrationData
    @Binding var sessionData: SessionData?
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSwingType: SwingType = .forehand
    @State private var capturedCounts: [SwingType: Int] = [.forehand: 0, .backhand: 0, .serve: 0]
    @State private var lastCapturedTime = Date()
    
    var body: some View {
        ZStack {
            // Regular camera view
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
            
            // Calibration UI Overlay
            VStack {
                // Top bar with calibration info
                VStack(spacing: 10) {
                    Text("CALIBRATION MODE")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    // Swing type selector
                    Picker("Type", selection: $currentSwingType) {
                        Text("Forehand").tag(SwingType.forehand)
                        Text("Backhand").tag(SwingType.backhand)
                        Text("Serve").tag(SwingType.serve)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Current counts
                    HStack(spacing: 20) {
                        CalibrationCount(type: .forehand, count: capturedCounts[.forehand] ?? 0, isActive: currentSwingType == .forehand)
                        CalibrationCount(type: .backhand, count: capturedCounts[.backhand] ?? 0, isActive: currentSwingType == .backhand)
                        CalibrationCount(type: .serve, count: capturedCounts[.serve] ?? 0, isActive: currentSwingType == .serve)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Instructions
                VStack(spacing: 10) {
                    Text("Perform \(currentSwingType.rawValue) swings")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Each swing will be saved as a \(currentSwingType.rawValue)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
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
                HStack(spacing: 20) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button(viewModel.isRecording ? "Stop" : "Start") {
                        if viewModel.isRecording {
                            sessionData = viewModel.stopRecording()
                            dismiss()
                        } else {
                            startCalibrationRecording()
                        }
                    }
                    .padding()
                    .frame(width: 120)
                    .background(viewModel.isRecording ? Color.orange : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Done") {
                        calibrationData.saveCalibration()
                        dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .opacity(hasMinimumCalibration() ? 1 : 0.5)
                    .disabled(!hasMinimumCalibration())
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            setupCalibrationMode()
        }
    }
    
    private func setupCalibrationMode() {
        viewModel.checkPermissions()
        
        // Set calibration mode
        calibrationData.isCalibrating = true
        calibrationData.calibratingType = currentSwingType
        
        // Override swing detection callback for calibration
        viewModel.visionService.onSwingDetected = { [self] detectedType, duration in
            // In calibration mode, we force the type to be what user selected
            if Date().timeIntervalSince(lastCapturedTime) > 2.0 {  // Prevent rapid captures
                
                // Get the metrics from the vision service
                if let metrics = viewModel.visionService.getSwingMetrics() {
                    calibrationData.addCalibrationSwing(metrics: metrics, forcedType: currentSwingType)
                    
                    DispatchQueue.main.async {
                        capturedCounts[currentSwingType, default: 0] += 1
                        lastCapturedTime = Date()
                        
                        // Feedback
                        viewModel.debugInfo = "\(currentSwingType.rawValue) captured! (\(capturedCounts[currentSwingType] ?? 0)/5)"
                        
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .heavy)  // Changed from .success to .heavy
                        impact.impactOccurred()
                        
                        AudioServicesPlaySystemSound(1057) // Success sound
                    }
                }
            }
        }
    }
    
    private func startCalibrationRecording() {
        viewModel.startRecording()
    }
    
    private func hasMinimumCalibration() -> Bool {
        return (capturedCounts[.forehand] ?? 0) >= 3 &&
               (capturedCounts[.backhand] ?? 0) >= 3 &&
               (capturedCounts[.serve] ?? 0) >= 3
    }
}

struct CalibrationCount: View {
    let type: SwingType
    let count: Int
    let isActive: Bool
    
    var body: some View {
        VStack {
            Text(type.rawValue)
                .font(.caption)
                .foregroundColor(isActive ? .yellow : .white)
            
            ZStack {
                Circle()
                    .stroke(isActive ? Color.yellow : Color.gray, lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Text("\(count)")
                    .font(.headline)
                    .foregroundColor(count >= 3 ? .green : .white)
            }
        }
    }
}
