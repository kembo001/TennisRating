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
    
    // Swing type tracking
    @Published var forehandCount = 0
    @Published var backhandCount = 0
    @Published var serveCount = 0
    
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    // Motion detection for swing
    private var previousPixelBuffer: CVPixelBuffer?
    private var motionHistory: [(zone: String, motion: Int)] = []
    private var isInSwingMotion = false
    private var swingStartTime: Date?
    private let ciContext = CIContext()
    
    // Timing tracking
    private var sessionStartTime: Date?
    private var lastShotTime: Date?
    private var shotTimings: [TimeInterval] = []
    
    // Motion zones for different swing types
    private let zones = [
        "topLeft": CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5),
        "topRight": CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5),
        "bottomLeft": CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.5),
        "bottomRight": CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
        "center": CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    ]
    
    override init() {
        super.init()
        setupSession()
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
        motionHistory.removeAll()
        sessionStartTime = Date()
        lastShotTime = nil
        debugInfo = "Ready - Make your swing!"
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

// MARK: - Swing Type Detection
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        detectSwingMotion(in: pixelBuffer)
    }
    
    private func detectSwingMotion(in pixelBuffer: CVPixelBuffer) {
        let currentImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let previousBuffer = previousPixelBuffer else {
            previousPixelBuffer = pixelBuffer
            return
        }
        
        let previousImage = CIImage(cvPixelBuffer: previousBuffer)
        
        // Calculate motion in each zone
        var zoneMotions: [(zone: String, motion: Int)] = []
        
        for (zoneName, zoneRect) in zones {
            let motion = calculateMotionInZone(current: currentImage, previous: previousImage, zone: zoneRect)
            if motion > 20 { // Only track significant motion
                zoneMotions.append((zone: zoneName, motion: motion))
            }
        }
        
        // Add to motion history
        if let strongestMotion = zoneMotions.max(by: { $0.motion < $1.motion }) {
            motionHistory.append(strongestMotion)
            if motionHistory.count > 30 { // Keep last 0.5 seconds
                motionHistory.removeFirst()
            }
        }
        
        // Analyze pattern
        analyzeSwingPattern()
        
        // Update previous frame
        previousPixelBuffer = pixelBuffer
    }
    
    private func calculateMotionInZone(current: CIImage, previous: CIImage, zone: CGRect) -> Int {
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else { return 0 }
        diffFilter.setValue(previous, forKey: kCIInputImageKey)
        diffFilter.setValue(current, forKey: kCIInputBackgroundImageKey)
        
        guard let outputImage = diffFilter.outputImage else { return 0 }
        
        // Calculate zone rectangle
        let extent = outputImage.extent
        let zoneRect = CGRect(
            x: extent.width * zone.origin.x,
            y: extent.height * zone.origin.y,
            width: extent.width * zone.width,
            height: extent.height * zone.height
        )
        
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return 0 }
        avgFilter.setValue(outputImage, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: zoneRect), forKey: "inputExtent")
        
        guard let avgOutput = avgFilter.outputImage else { return 0 }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(avgOutput,
                        toBitmap: &bitmap,
                        rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8,
                        colorSpace: nil)
        
        return Int(bitmap[0]) + Int(bitmap[1]) + Int(bitmap[2])
    }
    
    private func analyzeSwingPattern() {
        guard motionHistory.count >= 15 else { return }
        
        let totalMotion = motionHistory.suffix(15).reduce(0) { $0 + $1.motion }
        guard totalMotion > 500 else { return } // Minimum motion threshold
        
        if !isInSwingMotion {
            isInSwingMotion = true
            swingStartTime = Date()
            
            DispatchQueue.main.async {
                self.debugInfo = "Swing detected! Analyzing type..."
            }
            
        } else if let startTime = swingStartTime, Date().timeIntervalSince(startTime) > 0.5 {
            // Analyze swing type based on motion pattern
            let swingType = detectSwingType()
            
            // Register the swing
            registerSwing(type: swingType, duration: Date().timeIntervalSince(startTime))
            
            isInSwingMotion = false
            swingStartTime = nil
            motionHistory.removeAll()
        }
    }
    
    private func detectSwingType() -> SwingType {
        // Analyze motion pattern across zones
        let recentMotions = motionHistory.suffix(20)
        
        // Count motion in each zone
        var zoneCounts: [String: Int] = [:]
        var totalMotionByZone: [String: Int] = [:]
        
        for (zone, motion) in recentMotions {
            zoneCounts[zone, default: 0] += 1
            totalMotionByZone[zone, default: 0] += motion
        }
        
        // Detect patterns:
        
        // SERVE: Strong motion starting from top zones
        let topMotion = (totalMotionByZone["topLeft"] ?? 0) + (totalMotionByZone["topRight"] ?? 0)
        let bottomMotion = (totalMotionByZone["bottomLeft"] ?? 0) + (totalMotionByZone["bottomRight"] ?? 0)
        
        if topMotion > bottomMotion * 2 {
            // Check if motion starts high and goes down (serve pattern)
            let firstHalf = Array(recentMotions.prefix(10))
            let secondHalf = Array(recentMotions.suffix(10))
            
            let firstHalfTop = firstHalf.filter { $0.zone.contains("top") }.count
            let secondHalfBottom = secondHalf.filter { $0.zone.contains("bottom") }.count
            
            if firstHalfTop > 5 && secondHalfBottom > 3 {
                return .serve
            }
        }
        
        // FOREHAND vs BACKHAND: Based on left-right motion pattern
        let leftMotion = (totalMotionByZone["topLeft"] ?? 0) + (totalMotionByZone["bottomLeft"] ?? 0)
        let rightMotion = (totalMotionByZone["topRight"] ?? 0) + (totalMotionByZone["bottomRight"] ?? 0)
        
        // For right-handed player:
        // Forehand: Motion from right to left (across body)
        // Backhand: Motion from left to right
        
        if Double(rightMotion) > Double(leftMotion) * 1.3 {
            // Check motion progression
            let motionProgression = recentMotions.map { $0.zone }
            let rightToLeftCount = countTransitions(in: motionProgression, from: "Right", to: "Left")
            let leftToRightCount = countTransitions(in: motionProgression, from: "Left", to: "Right")
            
            if rightToLeftCount > leftToRightCount {
                return .forehand
            }
        } else if Double(leftMotion) > Double(rightMotion) * 1.3 {
            return .backhand
        }
        
        // Default to forehand if pattern unclear
        return .forehand
    }
    
    private func countTransitions(in zones: [String], from: String, to: String) -> Int {
        var count = 0
        for i in 0..<(zones.count - 1) {
            if zones[i].contains(from) && zones[i + 1].contains(to) {
                count += 1
            }
        }
        return count
    }
    
    private func registerSwing(type: SwingType, duration: TimeInterval) {
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
            
            // Success criteria based on swing type
            var isSuccess = true
            var feedback = "\(type.rawValue) detected!"
            
            // Different criteria for different swings
            switch type {
            case .serve:
                // Serves should be longer, more vertical motion
                if duration < 0.6 {
                    isSuccess = false
                    feedback += " - Full motion needed"
                }
            case .forehand, .backhand:
                // Ground strokes should be quicker
                if duration > 1.0 {
                    isSuccess = false
                    feedback += " - Too slow"
                } else if duration < 0.3 {
                    isSuccess = false
                    feedback += " - Too rushed"
                }
            case .unknown:
                isSuccess = false
                feedback = "Unclear swing - try again"
            }
            
            if isSuccess {
                self.successfulShots += 1
                AudioServicesPlaySystemSound(1057) // Success
            } else {
                AudioServicesPlaySystemSound(1053) // Error
            }
            
            self.debugInfo = feedback
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
}
