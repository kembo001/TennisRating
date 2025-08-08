import AVFoundation
import Vision
import SwiftUI
import CoreImage

enum SwingType: String {
    case forehand = "Forehand"
    case backhand = "Backhand"
    case serve = "Serve"
    case unknown = "Unknown"
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var totalShots = 0
    @Published var successfulShots = 0
    @Published var isSessionRunning = false
    @Published var cameraError: String?
    @Published var debugInfo = ""
    @Published var currentPoseFrame: PoseFrame?
    @Published var debugMetrics: EnhancedSwingDetector.DebugInfo?
    @Published var wristPath: [CGPoint] = []
    
    // Swing type tracking
    @Published var forehandCount = 0
    @Published var backhandCount = 0
    @Published var serveCount = 0
    
    // NEW: Machine Learning Data Collection
    @Published var collectedSwings: [LabeledSwingData] = []
    private var currentPoseSequence: [PoseFrameData] = []
    @Published var isCapturingSequence = false  // Changed from private to @Published
    private var sequenceStartTime: Date?
    
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    // Vision service for pose detection
    let visionService = VisionService()  // Made public for calibration access
    
    // Calibration data
    var calibrationData: SwingCalibrationData?
    
    // Timing tracking
    private var sessionStartTime: Date?
    private var lastShotTime: Date?
    private var shotTimings: [TimeInterval] = []
    
    // Swing detection cooldown to prevent double-counting
    private var lastSwingDetectionTime: Date?
    private let swingCooldownInterval: TimeInterval = 1.5 // Increased to 1.5 seconds between swings
    
    override init() {
        super.init()
        setupSession()
        setupVisionCallbacks()
        loadCollectedSwings()
    }
    
    func enableDebugMode(_ enabled: Bool) {
        visionService.enableDebugMode(enabled)
    }
    
    func setCalibrationData(_ data: SwingCalibrationData) {
        calibrationData = data
        visionService.calibrationData = data
    }
    
    // MARK: - Machine Learning Data Collection Methods
    
    func startCaptureSequence() {
        currentPoseSequence.removeAll()
        isCapturingSequence = true
        sequenceStartTime = Date()
        
        // Give a visual cue
        DispatchQueue.main.async {
            self.debugInfo = "🔴 RECORDING SWING..."
        }
        
        // Optional: Add haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    func stopAndSaveCaptureSequence(label: SwingType) {
        guard isCapturingSequence else { return }
        
        isCapturingSequence = false
        
        // Only save if we have a reasonable amount of data
        guard currentPoseSequence.count >= 10 else {
            DispatchQueue.main.async {
                self.debugInfo = "❌ Not enough pose data captured"
            }
            return
        }
        
        let newLabeledSwing = LabeledSwingData(
            label: label.rawValue,
            poseFrames: currentPoseSequence,
            sessionId: UUID(),
            timestamp: Date()
        )
        
        collectedSwings.append(newLabeledSwing)
        saveCollectedSwings()
        
        // Give a visual cue
        DispatchQueue.main.async {
            self.debugInfo = "✅ \(label.rawValue) captured! (\(self.collectedSwings.count) total)"
        }
        
        // Success haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Reset for next capture
        currentPoseSequence.removeAll()
        sequenceStartTime = nil
    }
    
    func cancelCaptureSequence() {
        isCapturingSequence = false
        currentPoseSequence.removeAll()
        sequenceStartTime = nil
        
        DispatchQueue.main.async {
            self.debugInfo = "❌ Capture cancelled"
        }
    }
    
    func clearAllCollectedSwings() {
        collectedSwings.removeAll()
        saveCollectedSwings()
        
        DispatchQueue.main.async {
            self.debugInfo = "🗑️ All collected swings cleared"
        }
    }
    
    func getCollectedSwingsSummary() -> String {
        let forehandCount = collectedSwings.filter { $0.label == "Forehand" }.count
        let backhandCount = collectedSwings.filter { $0.label == "Backhand" }.count
        let serveCount = collectedSwings.filter { $0.label == "Serve" }.count
        
        return "ML Data - FH: \(forehandCount), BH: \(backhandCount), S: \(serveCount)"
    }
    
    func exportCollectedSwings() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(collectedSwings)
    }
    
    // MARK: - Data Persistence
    
    private func saveCollectedSwings() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(collectedSwings)
            UserDefaults.standard.set(data, forKey: "collectedSwings")
        } catch {
            print("Failed to save collected swings: \(error)")
        }
    }
    
    private func loadCollectedSwings() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = UserDefaults.standard.data(forKey: "collectedSwings"),
           let loadedSwings = try? decoder.decode([LabeledSwingData].self, from: data) {
            collectedSwings = loadedSwings
        }
    }
    
    // MARK: - Vision Callbacks Setup
    
    private func setupVisionCallbacks() {
        // Handle pose updates for visualization AND data collection
        visionService.onPoseDetected = { [weak self] poseFrame in
            guard let self = self else { return }
            
            // Store pose data if we are in the middle of capturing a swing
            if self.isCapturingSequence {
                let frameData = PoseFrameData(
                    wrist: poseFrame.wrist?.location,
                    elbow: poseFrame.elbow?.location,
                    shoulder: poseFrame.shoulder?.location,
                    hip: poseFrame.hip?.location,
                    timestamp: poseFrame.timestamp.timeIntervalSince(self.sequenceStartTime ?? Date()),
                    confidence: self.calculateFrameConfidence(poseFrame)
                )
                self.currentPoseSequence.append(frameData)
                
                // Limit sequence length to prevent memory issues
                if self.currentPoseSequence.count > 120 { // ~4 seconds at 30fps
                    self.currentPoseSequence.removeFirst()
                }
            }
            
            DispatchQueue.main.async {
                self.currentPoseFrame = poseFrame
                // Update debug metrics
                self.debugMetrics = self.visionService.getDebugInfo()
                // Update wrist path
                if let metrics = self.visionService.getSwingMetrics() {
                    self.wristPath = metrics.path
                }
            }
        }
        
        // Handle swing detection - can be used for automatic capture or manual triggering
        visionService.onSwingDetected = { [weak self] swingType, duration in
            // If we're in manual capture mode (isCapturingSequence), don't auto-handle
            // This allows for manual control in calibration mode
            if self?.isCapturingSequence == false {
                self?.handleSwingDetection(type: swingType, duration: duration)
            }
        }
        
        // Handle debug messages
        visionService.debugCallback = { [weak self] message in
            // Only update debug info if we're not currently showing capture status
            if self?.isCapturingSequence == false {
                DispatchQueue.main.async {
                    self?.debugInfo = message
                }
            }
        }
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
    
    // MARK: - Original Swing Detection Logic
    
    private func handleSwingDetection(type: SwingType, duration: TimeInterval) {
        // Check cooldown to prevent double-counting
        if let lastTime = lastSwingDetectionTime,
           Date().timeIntervalSince(lastTime) < swingCooldownInterval {
            return
        }
        
        lastSwingDetectionTime = Date()
        
        // Track shot timing
        if let lastShot = lastShotTime {
            let interval = Date().timeIntervalSince(lastShot)
            shotTimings.append(interval)
        }
        lastShotTime = Date()
        
        DispatchQueue.main.async {
            self.totalShots += 1
            
            // Update swing type counts
            switch type {
            case .forehand:
                self.forehandCount += 1
            case .backhand:
                self.backhandCount += 1
            case .serve:
                self.serveCount += 1
            case .unknown:
                break
            }
            
            // Evaluate swing quality
            let (isSuccess, feedback) = self.evaluateSwingQuality(type: type, duration: duration)
            
            if isSuccess {
                self.successfulShots += 1
                AudioServicesPlaySystemSound(1057) // Success sound
            } else {
                AudioServicesPlaySystemSound(1053) // Error sound
            }
            
            self.debugInfo = feedback
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
    
    private func evaluateSwingQuality(type: SwingType, duration: TimeInterval) -> (success: Bool, feedback: String) {
        var isSuccess = true
        var feedback = "\(type.rawValue) detected!"
        
        switch type {
        case .serve:
            // Serves should have longer preparation
            if duration < 0.8 {
                isSuccess = false
                feedback += " - Take more time on preparation"
            } else if duration > 2.5 {
                isSuccess = false
                feedback += " - Too slow, increase racket speed"
            } else {
                feedback += " - Good rhythm!"
            }
            
        case .forehand, .backhand:
            // Ground strokes should be fluid and quick
            if duration < 0.4 {
                isSuccess = false
                feedback += " - Too rushed, focus on form"
            } else if duration > 1.5 {
                isSuccess = false
                feedback += " - Speed up your swing"
            } else {
                feedback += " - Nice stroke!"
            }
            
        case .unknown:
            isSuccess = false
            feedback = "Unclear swing - ensure full body is visible"
        }
        
        return (isSuccess, feedback)
    }
    
    // MARK: - Camera Session Management
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in
                self?.startSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async {
                        self?.startSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.cameraError = "Camera access denied. Please enable in Settings."
            }
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            return
        }
        captureSession.addInput(videoInput)
        
        // Add video output
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput,
              captureSession.canAddOutput(videoOutput) else {
            return
        }
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        captureSession.addOutput(videoOutput)
        
        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
        
        captureSession.commitConfiguration()
    }
    
    private func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        
        session.startRunning()
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
    }
    
    func startRecording() {
        isRecording = true
        totalShots = 0
        successfulShots = 0
        forehandCount = 0
        backhandCount = 0
        serveCount = 0
        shotTimings.removeAll()
        sessionStartTime = Date()
        lastShotTime = nil
        lastSwingDetectionTime = nil
        debugInfo = "Ready - Show your full body for best tracking"
    }
    
    func stopRecording() -> SessionData {
        isRecording = false
        let duration = Date().timeIntervalSince(sessionStartTime ?? Date())
        
        return SessionData(
            totalShots: totalShots,
            successfulShots: successfulShots,
            timestamp: Date(),
            sessionDuration: duration,
            shotTimings: shotTimings,
            forehandCount: forehandCount,
            backhandCount: backhandCount,
            serveCount: serveCount
        )
    }
}

// MARK: - Video Frame Processing
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Send frame to Vision service for pose detection
        visionService.processFrame(pixelBuffer)
    }
}
