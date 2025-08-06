import Vision
import AVFoundation
import CoreImage

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

class SwingDetector {
    private var poseHistory: [PoseFrame] = []
    private var currentPhase: SwingPhase = .idle
    private var swingStartTime: Date?
    private var peakBackswingPosition: CGPoint?
    
    // Thresholds for swing detection
    private let minSwingVelocity: CGFloat = 200.0 // pixels per second
    private let minSwingDistance: CGFloat = 100.0 // pixels
    private let maxSwingDuration: TimeInterval = 2.0
    private let historyWindowSize = 30 // frames (~1 second at 30fps)
    
    func addPoseFrame(_ frame: PoseFrame) {
        poseHistory.append(frame)
        
        // Keep only recent history
        if poseHistory.count > historyWindowSize {
            poseHistory.removeFirst()
        }
        
        // Analyze for swing
        analyzeSwing()
    }
    
    private func analyzeSwing() {
        guard poseHistory.count >= 10 else { return }
        
        switch currentPhase {
        case .idle:
            checkForBackswingStart()
        case .backswing:
            checkForForwardSwing()
        case .forward:
            checkForFollowThrough()
        case .followThrough:
            checkForCompletion()
        case .completed:
            resetDetection()
        }
    }
    
    private func checkForBackswingStart() {
        guard let recentFrames = getValidRecentFrames(count: 5) else { return }
        
        // Check if wrist is moving backwards (increasing X for right-handed)
        let wristVelocity = calculateWristVelocity(frames: recentFrames)
        
        if abs(wristVelocity.x) > minSwingVelocity / 3 {
            currentPhase = .backswing
            swingStartTime = Date()
            
            if let lastFrame = recentFrames.last,
               let wrist = lastFrame.wrist {
                peakBackswingPosition = wrist.location
            }
        }
    }
    
    private func checkForForwardSwing() {
        guard let recentFrames = getValidRecentFrames(count: 5),
              let startTime = swingStartTime else { return }
        
        // Timeout check
        if Date().timeIntervalSince(startTime) > maxSwingDuration {
            resetDetection()
            return
        }
        
        let wristVelocity = calculateWristVelocity(frames: recentFrames)
        
        // Check for direction change (forward swing)
        if wristVelocity.x < -minSwingVelocity { // Moving left for right-handed forehand
            currentPhase = .forward
        }
        
        // Update peak position
        if let currentWrist = recentFrames.last?.wrist {
            if let peak = peakBackswingPosition {
                if currentWrist.location.x > peak.x {
                    peakBackswingPosition = currentWrist.location
                }
            }
        }
    }
    
    private func checkForFollowThrough() {
        guard let recentFrames = getValidRecentFrames(count: 5) else { return }
        
        let wristVelocity = calculateWristVelocity(frames: recentFrames)
        
        // Check if swing is slowing down
        if abs(wristVelocity.x) < minSwingVelocity / 2 {
            currentPhase = .followThrough
        }
    }
    
    private func checkForCompletion() {
        guard let peak = peakBackswingPosition,
              let currentFrame = poseHistory.last,
              let wrist = currentFrame.wrist else { return }
        
        // Check if wrist has traveled sufficient distance
        let swingDistance = abs(wrist.location.x - peak.x)
        
        if swingDistance > minSwingDistance {
            currentPhase = .completed
        } else {
            // Not a valid swing, reset
            resetDetection()
        }
    }
    
    private func resetDetection() {
        currentPhase = .idle
        swingStartTime = nil
        peakBackswingPosition = nil
    }
    
    private func getValidRecentFrames(count: Int) -> [PoseFrame]? {
        let recentFrames = Array(poseHistory.suffix(count))
        let validFrames = recentFrames.filter { $0.isValidFrame }
        return validFrames.count >= count ? validFrames : nil
    }
    
    private func calculateWristVelocity(frames: [PoseFrame]) -> CGPoint {
        guard frames.count >= 2,
              let firstWrist = frames.first?.wrist,
              let lastWrist = frames.last?.wrist else {
            return .zero
        }
        
        let timeDiff = lastWrist.timestamp.timeIntervalSince(firstWrist.timestamp)
        guard timeDiff > 0 else { return .zero }
        
        let dx = lastWrist.location.x - firstWrist.location.x
        let dy = lastWrist.location.y - firstWrist.location.y
        
        return CGPoint(x: dx / timeDiff, y: dy / timeDiff)
    }
    
    func detectSwingType(from frames: [PoseFrame]) -> SwingType {
        guard frames.count >= 10 else { return .unknown }
        
        // Analyze trajectory patterns
        let validFrames = frames.filter { $0.isValidFrame }
        guard validFrames.count >= 5 else { return .unknown }
        
        // Check vertical movement for serve
        if let firstWrist = validFrames.first?.wrist,
           let lastWrist = validFrames.last?.wrist {
            
            let verticalMovement = firstWrist.location.y - lastWrist.location.y
            let horizontalMovement = abs(lastWrist.location.x - firstWrist.location.x)
            
            // Serve: Strong vertical movement
            if verticalMovement > 150 && verticalMovement > horizontalMovement {
                return .serve
            }
            
            // Forehand vs Backhand (for right-handed player)
            // Analyze elbow-wrist relationship
            if let firstElbow = validFrames.first?.elbow,
               let lastElbow = validFrames.last?.elbow {
                
                // Forehand: Wrist crosses body from right to left
                // Backhand: Wrist moves from left to right
                let wristCrossing = lastWrist.location.x - firstWrist.location.x
                let elbowMovement = lastElbow.location.x - firstElbow.location.x
                
                if wristCrossing < -100 { // Strong leftward movement
                    return .forehand
                } else if wristCrossing > 100 { // Strong rightward movement
                    return .backhand
                }
            }
        }
        
        return .unknown
    }
    
    var isSwingComplete: Bool {
        return currentPhase == .completed
    }
    
    func getSwingFrames() -> [PoseFrame] {
        return poseHistory
    }
}

// MARK: - Vision Service
class VisionService: NSObject {
    private let sequenceHandler = VNSequenceRequestHandler()
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private let swingDetector = SwingDetector()
    
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
                self?.debugCallback?("No person detected")
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
        
        // Determine which wrist is active (higher confidence or more movement)
        let activeWrist = (rightWrist?.confidence ?? 0) > (leftWrist?.confidence ?? 0) ? rightWrist : leftWrist
        let activeElbow = (rightWrist?.confidence ?? 0) > (leftWrist?.confidence ?? 0) ? rightElbow : leftElbow
        
        // Create pose frame
        let timestamp = Date()
        let poseFrame = PoseFrame(
            timestamp: timestamp,
            wrist: activeWrist.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) },
            elbow: activeElbow.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) },
            shoulder: rightShoulder.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) },
            hip: rightHip.map { PosePoint(location: $0.location, confidence: $0.confidence, timestamp: timestamp) }
        )
        
        // Send to callback for visualization
        onPoseDetected?(poseFrame)
        
        // Add to swing detector
        swingDetector.addPoseFrame(poseFrame)
        
        // Check for completed swing
        if swingDetector.isSwingComplete {
            let swingFrames = swingDetector.getSwingFrames()
            let swingType = swingDetector.detectSwingType(from: swingFrames)
            let duration = calculateSwingDuration(frames: swingFrames)
            
            debugCallback?("\(swingType.rawValue) detected! Duration: \(String(format: "%.2f", duration))s")
            onSwingDetected?(swingType, duration)
            
            // Reset for next swing
            swingDetector.addPoseFrame(poseFrame) // Start fresh with current frame
        }
        
        // Debug info
        if let wrist = activeWrist, wrist.confidence > 0.5 {
            debugCallback?("Tracking wrist (confidence: \(String(format: "%.2f", wrist.confidence)))")
        }
    }
    
    private func calculateSwingDuration(frames: [PoseFrame]) -> TimeInterval {
        guard let first = frames.first,
              let last = frames.last else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }
}
