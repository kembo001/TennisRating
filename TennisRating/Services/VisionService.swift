import Vision
import AVFoundation
import CoreImage
import SwiftUI

// MARK: - Pose Point Tracking
struct PosePoint {
    let location: CGPoint
    let confidence: Float
    let timestamp: Date
}

struct PoseFrame {
    let timestamp: Date
    let wrist: PosePoint?
    let elbow: PosePoint?
    let shoulder: PosePoint?
    let hip: PosePoint?
    
    var isValidFrame: Bool {
        // Need at least wrist and elbow for swing detection
        return wrist != nil && elbow != nil
    }
}

// MARK: - Swing Detection State
enum SwingPhase {
    case idle
    case backswing
    case forward
    case followThrough
    case completed
}

// MARK: - Swing Metrics
struct SwingMetrics {
    let maxSpeed: CGFloat
    let amplitude: CGFloat
    let duration: TimeInterval
    let path: [CGPoint]
}

// MARK: - Enhanced Swing Detector with Debug Info
class EnhancedSwingDetector {
    private var poseHistory: [PoseFrame] = []
    private var currentPhase: SwingPhase = .idle
    private var swingStartTime: Date?
    
    // Tracking for swing analysis
    private var wristPath: [CGPoint] = []
    private var maxWristSpeed: CGFloat = 0
    private var swingAmplitude: CGFloat = 0
    
    // Debug mode
    var debugMode = true
    var debugInfo: DebugInfo?
    
    struct DebugInfo {
        let wristSpeed: CGFloat
        let elbowAngle: CGFloat
        let shoulderRotation: CGFloat
        let swingPhase: SwingPhase
        let motionDirection: String
        let confidence: Float
    }
    
    // Adjustable thresholds (tune these based on testing)
    struct Thresholds {
        static let minSwingSpeed: CGFloat = 500.0  // Increased to avoid false positives
        static let minBackswingDistance: CGFloat = 100.0
        static let minForwardSpeed: CGFloat = 800.0  // Increased for real swings
        static let maxIdleSpeed: CGFloat = 200.0  // Increased idle threshold
        static let minConfidence: Float = 0.6
        static let minSwingDuration: TimeInterval = 0.3  // Minimum swing time
        static let maxSwingDuration: TimeInterval = 2.0  // Maximum swing time
    }
    
    func addPoseFrame(_ frame: PoseFrame) {
        poseHistory.append(frame)
        
        // Keep last 60 frames (2 seconds at 30fps)
        if poseHistory.count > 60 {
            poseHistory.removeFirst()
        }
        
        // Track wrist path
        if let wrist = frame.wrist, wrist.confidence > Thresholds.minConfidence {
            wristPath.append(wrist.location)
            if wristPath.count > 60 {
                wristPath.removeFirst()
            }
        }
        
        analyzeSwingWithDebug()
    }
    
    private func analyzeSwingWithDebug() {
        guard poseHistory.count >= 5 else { return }
        
        let recentFrames = Array(poseHistory.suffix(10))
        guard let currentFrame = recentFrames.last else { return }
        
        // Calculate metrics
        let wristSpeed = calculateWristSpeed(frames: recentFrames)
        let elbowAngle = calculateElbowAngle(frame: currentFrame)
        let shoulderRotation = calculateShoulderRotation(frames: recentFrames)
        let motionDirection = getMotionDirection(frames: recentFrames)
        let avgConfidence = calculateAverageConfidence(frame: currentFrame)
        
        // Update debug info
        if debugMode {
            debugInfo = DebugInfo(
                wristSpeed: wristSpeed,
                elbowAngle: elbowAngle,
                shoulderRotation: shoulderRotation,
                swingPhase: currentPhase,
                motionDirection: motionDirection,
                confidence: avgConfidence
            )
        }
        
        // State machine with improved detection
        switch currentPhase {
        case .idle:
            // Detect backswing start - look for wrist moving away from rest position
            if wristSpeed > Thresholds.minSwingSpeed &&
               (motionDirection == "right" || motionDirection == "up") {
                currentPhase = .backswing
                swingStartTime = Date()
                wristPath.removeAll()
                maxWristSpeed = 0
            }
            
        case .backswing:
            // Track max speed and amplitude
            maxWristSpeed = max(maxWristSpeed, wristSpeed)
            
            // Detect transition to forward swing (direction change + acceleration)
            if motionDirection == "left" && wristSpeed > Thresholds.minForwardSpeed {
                currentPhase = .forward
                swingAmplitude = calculateSwingAmplitude()
            }
            
            // Timeout
            if let start = swingStartTime, Date().timeIntervalSince(start) > 3.0 {
                resetDetection()
            }
            
        case .forward:
            // Track through the forward swing
            maxWristSpeed = max(maxWristSpeed, wristSpeed)
            
            // Detect follow-through when speed decreases
            if wristSpeed < maxWristSpeed * 0.5 {
                currentPhase = .followThrough
            }
            
        case .followThrough:
            // Complete the swing when motion nearly stops
            if wristSpeed < Thresholds.maxIdleSpeed {
                currentPhase = .completed
            }
            
        case .completed:
            // Swing is complete, will be handled by parent
            break
        }
    }
    
    private func calculateWristSpeed(frames: [PoseFrame]) -> CGFloat {
        guard frames.count >= 2,
              let firstWrist = frames[frames.count - 2].wrist,
              let lastWrist = frames.last?.wrist,
              firstWrist.confidence > Thresholds.minConfidence,
              lastWrist.confidence > Thresholds.minConfidence else {
            return 0
        }
        
        let dx = (lastWrist.location.x - firstWrist.location.x) * 1920 // Convert to pixels
        let dy = (lastWrist.location.y - firstWrist.location.y) * 1080
        let distance = sqrt(dx * dx + dy * dy)
        
        let timeDiff = lastWrist.timestamp.timeIntervalSince(firstWrist.timestamp)
        guard timeDiff > 0 else { return 0 }
        
        return distance / timeDiff
    }
    
    private func calculateElbowAngle(frame: PoseFrame) -> CGFloat {
        guard let wrist = frame.wrist,
              let elbow = frame.elbow,
              let shoulder = frame.shoulder,
              wrist.confidence > Thresholds.minConfidence,
              elbow.confidence > Thresholds.minConfidence,
              shoulder.confidence > Thresholds.minConfidence else {
            return 0
        }
        
        // Calculate angle between shoulder-elbow-wrist
        let v1 = CGVector(
            dx: shoulder.location.x - elbow.location.x,
            dy: shoulder.location.y - elbow.location.y
        )
        let v2 = CGVector(
            dx: wrist.location.x - elbow.location.x,
            dy: wrist.location.y - elbow.location.y
        )
        
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let det = v1.dx * v2.dy - v1.dy * v2.dx
        let angle = atan2(det, dot) * 180 / .pi
        
        return abs(angle)
    }
    
    private func calculateShoulderRotation(frames: [PoseFrame]) -> CGFloat {
        guard frames.count >= 2,
              let firstShoulder = frames.first?.shoulder,
              let lastShoulder = frames.last?.shoulder,
              firstShoulder.confidence > Thresholds.minConfidence,
              lastShoulder.confidence > Thresholds.minConfidence else {
            return 0
        }
        
        let rotation = abs(lastShoulder.location.x - firstShoulder.location.x) * 1920
        return rotation
    }
    
    private func getMotionDirection(frames: [PoseFrame]) -> String {
        guard frames.count >= 2,
              let firstWrist = frames[frames.count - 2].wrist,
              let lastWrist = frames.last?.wrist else {
            return "none"
        }
        
        let dx = lastWrist.location.x - firstWrist.location.x
        let dy = lastWrist.location.y - firstWrist.location.y
        
        if abs(dx) > abs(dy) {
            return dx > 0 ? "right" : "left"
        } else {
            return dy > 0 ? "down" : "up"
        }
    }
    
    private func calculateAverageConfidence(frame: PoseFrame) -> Float {
        var totalConfidence: Float = 0
        var count: Float = 0
        
        if let wrist = frame.wrist {
            totalConfidence += wrist.confidence
            count += 1
        }
        if let elbow = frame.elbow {
            totalConfidence += elbow.confidence
            count += 1
        }
        if let shoulder = frame.shoulder {
            totalConfidence += shoulder.confidence
            count += 1
        }
        
        return count > 0 ? totalConfidence / count : 0
    }
    
    private func calculateSwingAmplitude() -> CGFloat {
        guard wristPath.count >= 2 else { return 0 }
        
        let minX = wristPath.map { $0.x }.min() ?? 0
        let maxX = wristPath.map { $0.x }.max() ?? 0
        
        return (maxX - minX) * 1920 // Convert to pixels
    }
    
    func detectSwingType() -> SwingType {
        // Use collected metrics to determine swing type
        guard swingAmplitude > 100, maxWristSpeed > Thresholds.minForwardSpeed else {
            return .unknown
        }
        
        // Analyze wrist path shape for swing classification
        guard wristPath.count >= 10 else {
            return .unknown
        }
        
        let firstPoint = wristPath.first!
        let midPoint = wristPath[wristPath.count / 2]
        let lastPoint = wristPath.last!
        
        // Calculate key metrics
        let horizontalChange = (lastPoint.x - firstPoint.x) * 1920
        let verticalChange = (firstPoint.y - lastPoint.y) * 1080
        let midVerticalChange = (firstPoint.y - midPoint.y) * 1080
        
        // Calculate path curvature (how much the path curves)
        let directDistance = sqrt(pow(lastPoint.x - firstPoint.x, 2) + pow(lastPoint.y - firstPoint.y, 2))
        let pathLength = calculatePathLength()
        let curvature = pathLength / max(directDistance, 0.01)
        
        // SERVE DETECTION - Most distinctive pattern
        // Serves have strong vertical component and start high
        if firstPoint.y < 0.4 &&  // Starts in upper half of frame
           verticalChange > 200 &&  // Strong downward motion
           abs(verticalChange) > abs(horizontalChange) * 1.5 &&  // More vertical than horizontal
           curvature > 1.3 {  // Curved path (not straight line)
            return .serve
        }
        
        // GROUND STROKES - Distinguish by direction and starting position
        // For right-handed player
        
        // Calculate average Y position (height of swing)
        let avgY = wristPath.reduce(0.0) { $0 + $1.y } / CGFloat(wristPath.count)
        
        // Ground strokes typically happen in middle third of frame
        if avgY > 0.3 && avgY < 0.7 {
            
            // FOREHAND: Starts from player's right side, moves left
            if firstPoint.x > 0.5 &&  // Starts on right side
               horizontalChange < -200 &&  // Strong leftward motion
               abs(horizontalChange) > abs(verticalChange) {  // More horizontal than vertical
                return .forehand
            }
            
            // BACKHAND: Starts from player's left side, moves right
            if firstPoint.x < 0.5 &&  // Starts on left side
               horizontalChange > 200 &&  // Strong rightward motion
               abs(horizontalChange) > abs(verticalChange) {  // More horizontal than vertical
                return .backhand
            }
            
            // Alternative detection based on motion alone
            if abs(horizontalChange) > 150 {
                if horizontalChange < 0 {
                    return .forehand  // Any significant right-to-left
                } else {
                    return .backhand  // Any significant left-to-right
                }
            }
        }
        
        return .unknown
    }
    
    private func calculatePathLength() -> CGFloat {
        guard wristPath.count > 1 else { return 0 }
        
        var length: CGFloat = 0
        for i in 1..<wristPath.count {
            let dx = wristPath[i].x - wristPath[i-1].x
            let dy = wristPath[i].y - wristPath[i-1].y
            length += sqrt(dx * dx + dy * dy)
        }
        return length
    }
    
    private func resetDetection() {
        currentPhase = .idle
        swingStartTime = nil
        wristPath.removeAll()
        maxWristSpeed = 0
        swingAmplitude = 0
    }
    
    func reset() {  // Public method with different name
        resetDetection()
    }
    
    var isSwingComplete: Bool {
        return currentPhase == .completed
    }
    
    func getSwingMetrics() -> SwingMetrics {
        return SwingMetrics(
            maxSpeed: maxWristSpeed,
            amplitude: swingAmplitude,
            duration: swingStartTime.map { Date().timeIntervalSince($0) } ?? 0,
            path: wristPath
        )
    }
}

// MARK: - Vision Service with Enhanced Detection
class VisionService: NSObject {
    private let sequenceHandler = VNSequenceRequestHandler()
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    let swingDetector = EnhancedSwingDetector()
    var calibrationData: SwingCalibrationData?  // Add calibration data
    
    // Callbacks
    var onSwingDetected: ((SwingType, TimeInterval) -> Void)?
    var onPoseDetected: ((PoseFrame) -> Void)?
    var debugCallback: ((String) -> Void)?
    
    override init() {
        super.init()
        setupPoseDetection()
    }
    
    private func setupPoseDetection() {
        poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            if let error = error {
                self?.debugCallback?("Pose detection error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                self?.debugCallback?("No person detected - stand in frame")
                return
            }
            
            self?.processPoseObservation(observation)
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let request = poseRequest else { return }
        
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            debugCallback?("Failed to process frame: \(error.localizedDescription)")
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation) {
        // Extract key points for tennis swing
        let rightWrist = try? observation.recognizedPoint(.rightWrist)
        let rightElbow = try? observation.recognizedPoint(.rightElbow)
        let rightShoulder = try? observation.recognizedPoint(.rightShoulder)
        let rightHip = try? observation.recognizedPoint(.rightHip)
        
        // Also check left side for backhand
        let leftWrist = try? observation.recognizedPoint(.leftWrist)
        let leftElbow = try? observation.recognizedPoint(.leftElbow)
        let leftShoulder = try? observation.recognizedPoint(.leftShoulder)
        
        // Improved wrist selection based on movement and confidence
        var activeWrist: VNRecognizedPoint?
        var activeElbow: VNRecognizedPoint?
        var activeShoulder: VNRecognizedPoint?
        
        // Calculate which wrist has more movement (use right as default for right-handed players)
        let rightConfidence = rightWrist?.confidence ?? 0
        let leftConfidence = leftWrist?.confidence ?? 0
        
        // Prefer right hand for most shots (assuming right-handed player)
        // Only use left if right confidence is very low or for specific backhand detection
        if rightConfidence > 0.3 {
            activeWrist = rightWrist
            activeElbow = rightElbow
            activeShoulder = rightShoulder
        } else if leftConfidence > 0.3 {
            activeWrist = leftWrist
            activeElbow = leftElbow
            activeShoulder = leftShoulder
        }
        
        // Create pose frame
        let timestamp = Date()
        let poseFrame = PoseFrame(
            timestamp: timestamp,
            wrist: activeWrist.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) },
            elbow: activeElbow.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) },
            shoulder: activeShoulder.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) },
            hip: rightHip.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) }
        )
        
        // Send to callback for visualization
        onPoseDetected?(poseFrame)
        
        // Add to swing detector
        swingDetector.addPoseFrame(poseFrame)
        
        // Check for completed swing
        if swingDetector.isSwingComplete {
            let metrics = swingDetector.getSwingMetrics()
            
            // Only register if it's a valid swing duration
            if metrics.duration >= EnhancedSwingDetector.Thresholds.minSwingDuration &&
               metrics.duration <= EnhancedSwingDetector.Thresholds.maxSwingDuration &&
               metrics.maxSpeed > EnhancedSwingDetector.Thresholds.minForwardSpeed {
                
                // Determine swing type - use calibration if available
                let swingType: SwingType
                if let calibration = calibrationData,
                   calibration.hasCalibration(),
                   let firstPoint = metrics.path.first {
                    // Use calibrated classification
                    swingType = calibration.classifySwing(metrics: metrics, startX: firstPoint.x)
                } else {
                    // Use default detection
                    swingType = swingDetector.detectSwingType()
                }
                
                debugCallback?("\(swingType.rawValue) detected! Speed: \(Int(metrics.maxSpeed)) px/s")
                onSwingDetected?(swingType, metrics.duration)
            }
            
            // Reset detector for next swing
            swingDetector.reset()  // Always reset after checking
        }
    }
    
    func enableDebugMode(_ enabled: Bool) {
        swingDetector.debugMode = enabled
    }
    
    func getDebugInfo() -> EnhancedSwingDetector.DebugInfo? {
        return swingDetector.debugInfo
    }
    
    func getSwingMetrics() -> SwingMetrics? {
        return swingDetector.getSwingMetrics()
    }
}
