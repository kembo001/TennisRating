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
        let classificationScores: (forehand: Double, backhand: Double, serve: Double)?  // Add scores
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
            // Calculate classification scores if we have calibration data
            var scores: (forehand: Double, backhand: Double, serve: Double)? = nil
            
            if currentPhase == .forward || currentPhase == .followThrough {
                // Only calculate scores during active swing phases
                scores = calculateCurrentClassificationScores()
            }
            
            debugInfo = DebugInfo(
                wristSpeed: wristSpeed,
                elbowAngle: elbowAngle,
                shoulderRotation: shoulderRotation,
                swingPhase: currentPhase,
                motionDirection: motionDirection,
                confidence: avgConfidence,
                classificationScores: scores
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
        let lastPoint = wristPath.last!
        let firstQuarter = wristPath[wristPath.count / 4]
        let midPoint = wristPath[wristPath.count / 2]
        let thirdQuarter = wristPath[3 * wristPath.count / 4]
        
        // Calculate key metrics
        let horizontalChange = (lastPoint.x - firstPoint.x) * 1920
        let verticalChange = (firstPoint.y - lastPoint.y) * 1080
        
        // Calculate path characteristics
        let startHeight = firstPoint.y
        let endHeight = lastPoint.y
        let maxHeight = wristPath.map { $0.y }.min() ?? 0  // min because y=0 is top
        let minHeight = wristPath.map { $0.y }.max() ?? 1
        
        // Calculate average height of swing
        let avgHeight = wristPath.reduce(0.0) { $0 + $1.y } / CGFloat(wristPath.count)
        
        // Debug output
        print("Swing Analysis:")
        print("  Horizontal: \(horizontalChange)")
        print("  Vertical: \(verticalChange)")
        print("  Start Height: \(startHeight)")
        print("  Avg Height: \(avgHeight)")
        print("  Start X: \(firstPoint.x)")
        
        // SERVE DETECTION - Look for high start and downward motion
        if startHeight < 0.35 &&  // Starts in upper third
           verticalChange > 150 &&  // Strong downward component
           (maxHeight < 0.3) &&  // Reaches high point
           abs(verticalChange) > abs(horizontalChange) * 0.8 {  // More vertical than horizontal
            print("  Decision: SERVE (high start, downward motion)")
            return .serve
        }
        
        // GROUND STROKES - Must be in reasonable hitting zone
        if avgHeight > 0.35 && avgHeight < 0.75 {  // Middle zone
            
            // Check for consistent horizontal motion direction
            let firstHalfHorizontal = (midPoint.x - firstPoint.x) * 1920
            let secondHalfHorizontal = (lastPoint.x - midPoint.x) * 1920
            
            // FOREHAND: Consistent right-to-left motion
            if horizontalChange < -150 &&  // Overall leftward
               firstHalfHorizontal < -50 &&  // First half going left
               secondHalfHorizontal < -50 &&  // Second half still going left
               firstPoint.x > 0.4 {  // Starts from right side
                print("  Decision: FOREHAND (consistent R->L)")
                return .forehand
            }
            
            // BACKHAND: Consistent left-to-right motion
            if horizontalChange > 150 &&  // Overall rightward
               firstHalfHorizontal > 50 &&  // First half going right
               secondHalfHorizontal > 50 &&  // Second half still going right
               firstPoint.x < 0.6 {  // Starts from left side
                print("  Decision: BACKHAND (consistent L->R)")
                return .backhand
            }
            
            // Fallback: Use simple horizontal direction
            if abs(horizontalChange) > 100 {
                if horizontalChange < 0 {
                    print("  Decision: FOREHAND (fallback)")
                    return .forehand
                } else {
                    print("  Decision: BACKHAND (fallback)")
                    return .backhand
                }
            }
        }
        
        print("  Decision: UNKNOWN")
        return .unknown
    }
    
    private func calculateCurrentClassificationScores() -> (forehand: Double, backhand: Double, serve: Double)? {
        // This is a simplified scoring for debug display
        guard wristPath.count >= 5 else { return nil }
        
        let firstPoint = wristPath.first!
        let lastPoint = wristPath.last!
        
        let horizontalChange = (lastPoint.x - firstPoint.x) * 1920
        let verticalChange = (firstPoint.y - lastPoint.y) * 1080
        
        // Simple scoring based on motion direction
        var fhScore = 0.0
        var bhScore = 0.0
        var sScore = 0.0
        
        // Serve: vertical motion
        if abs(verticalChange) > 100 {
            sScore = min(abs(verticalChange) / 300.0, 1.0)
        }
        
        // Forehand: right to left
        if horizontalChange < -100 {
            fhScore = min(abs(horizontalChange) / 300.0, 1.0)
        }
        
        // Backhand: left to right
        if horizontalChange > 100 {
            bhScore = min(horizontalChange / 300.0, 1.0)
        }
        
        return (fhScore, bhScore, sScore)
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
