import AVFoundation
import Vision
import SwiftUI
import Combine

class CameraViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var totalShots = 0
    @Published var successfulShots = 0
    @Published var isSessionRunning = false
    @Published var cameraError: String?
    
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    // Simple motion detection
    private var shotDetectionCooldown = 0
    
    override init() {
        super.init()
        print("CameraViewModel: Initializing")
        setupSession()
    }
    
    func checkPermissions() {
        print("CameraViewModel: Checking permissions")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("CameraViewModel: Camera authorized")
            sessionQueue.async { [weak self] in
                self?.startSession()
            }
        case .notDetermined:
            print("CameraViewModel: Camera permission not determined")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("CameraViewModel: Camera permission granted: \(granted)")
                if granted {
                    self?.sessionQueue.async {
                        self?.startSession()
                    }
                }
            }
        case .denied:
            print("CameraViewModel: Camera access denied")
            DispatchQueue.main.async {
                self.cameraError = "Camera access denied. Please enable in Settings."
            }
        case .restricted:
            print("CameraViewModel: Camera access restricted")
            DispatchQueue.main.async {
                self.cameraError = "Camera access restricted."
            }
        @unknown default:
            print("CameraViewModel: Unknown camera permission state")
        }
    }
    
    private func setupSession() {
        print("CameraViewModel: Setting up session")
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            print("CameraViewModel: Failed to create capture session")
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("CameraViewModel: No video device found")
            DispatchQueue.main.async {
                self.cameraError = "No camera found"
            }
            return
        }
        
        print("CameraViewModel: Found video device: \(videoDevice.localizedName)")
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                print("CameraViewModel: Added video input")
            } else {
                print("CameraViewModel: Cannot add video input")
                DispatchQueue.main.async {
                    self.cameraError = "Cannot add camera input"
                }
                return
            }
        } catch {
            print("CameraViewModel: Error creating video input: \(error)")
            DispatchQueue.main.async {
                self.cameraError = "Camera error: \(error.localizedDescription)"
            }
            return
        }
        
        // Add video output
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput else {
            print("CameraViewModel: Failed to create video output")
            return
        }
        
        if captureSession.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            captureSession.addOutput(videoOutput)
            print("CameraViewModel: Added video output")
        } else {
            print("CameraViewModel: Cannot add video output")
        }
        
        captureSession.commitConfiguration()
        print("CameraViewModel: Session configuration committed")
    }
    
    private func startSession() {
        guard let session = captureSession else {
            print("CameraViewModel: No capture session to start")
            return
        }
        
        if !session.isRunning {
            print("CameraViewModel: Starting capture session")
            session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = session.isRunning
                print("CameraViewModel: Session running: \(session.isRunning)")
            }
        } else {
            print("CameraViewModel: Session already running")
        }
    }
    
    func startRecording() {
        print("CameraViewModel: Start recording")
        isRecording = true
        totalShots = 0
        successfulShots = 0
        shotDetectionCooldown = 0
    }
    
    func stopRecording() -> SessionData {
        print("CameraViewModel: Stop recording - Total shots: \(totalShots), Successful: \(successfulShots)")
        isRecording = false
        return SessionData(
            totalShots: totalShots,
            successfulShots: successfulShots,
            timestamp: Date()
        )
    }
}

// MARK: - Video Frame Processing
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        
        // Cooldown to avoid counting same shot multiple times
        if shotDetectionCooldown > 0 {
            shotDetectionCooldown -= 1
        }
        
        // Simple motion detection - for testing, detect a shot every 2 seconds
        if shotDetectionCooldown == 0 {
            DispatchQueue.main.async {
                self.totalShots += 1
                // Randomly mark as successful (60% success rate for demo)
                if Int.random(in: 0...9) < 6 {
                    self.successfulShots += 1
                }
                print("CameraViewModel: Shot detected! Total: \(self.totalShots)")
            }
            shotDetectionCooldown = 120 // 2 seconds at 60fps
        }
    }
}
