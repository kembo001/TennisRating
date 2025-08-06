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
    
    // Swing type tracking
    @Published var forehandCount = 0
    @Published var backhandCount = 0
    @Published var serveCount = 0
    
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    // Vision service for pose detection
    private let visionService = VisionService()
    
    // Timing tracking
    private var sessionStartTime: Date?
    private var lastShotTime: Date?
    private var shotTimings: [TimeInterval] = []
    
    // Swing detection cooldown to prevent double-counting
    private var lastSwingDetectionTime: Date?
    private let swingCooldownInterval: TimeInterval = 1.0 // 1 second between swings
    
    override init() {
        super.init()
        setupSession()
        setupVisionCallbacks()
    }
    
    private func setupVisionCallbacks() {
        // Handle swing detection
        visionService.onSwingDetected = { [weak self] swingType, duration in
            self?.handleSwingDetection(type: swingType, duration: duration)
        }
        
        // Handle pose updates for visualization
        visionService.onPoseDetected = { [weak self] poseFrame in
            DispatchQueue.main.async {
                self?.currentPoseFrame = poseFrame
            }
        }
        
        // Handle debug messages
        visionService.debugCallback = { [weak self] message in
            DispatchQueue.main.async {
                self?.debugInfo = message
            }
        }
    }
    
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
