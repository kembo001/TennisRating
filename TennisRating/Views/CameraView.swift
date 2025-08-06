import SwiftUI
import AVFoundation

// MARK: - Pose Overlay View
struct PoseOverlay: View {
    let poseFrame: PoseFrame?
    let geometrySize: CGSize
    
    var body: some View {
        Canvas { context, size in
            guard let pose = poseFrame else { return }
            
            // Convert normalized coordinates to screen coordinates
            let convertPoint: (CGPoint) -> CGPoint = { point in
                CGPoint(
                    x: point.x * size.width,
                    y: (1 - point.y) * size.height // Flip Y coordinate
                )
            }
            
            // Draw skeleton connections
            context.stroke(
                Path { path in
                    // Arm connection: shoulder -> elbow -> wrist
                    if let shoulder = pose.shoulder,
                       let elbow = pose.elbow {
                        path.move(to: convertPoint(shoulder.location))
                        path.addLine(to: convertPoint(elbow.location))
                    }
                    
                    if let elbow = pose.elbow,
                       let wrist = pose.wrist {
                        path.move(to: convertPoint(elbow.location))
                        path.addLine(to: convertPoint(wrist.location))
                    }
                    
                    // Torso: shoulder -> hip
                    if let shoulder = pose.shoulder,
                       let hip = pose.hip {
                        path.move(to: convertPoint(shoulder.location))
                        path.addLine(to: convertPoint(hip.location))
                    }
                },
                with: .color(.green),
                lineWidth: 3
            )
            
            // Draw joints as circles
            // Draw wrist (most important for swing)
            if let wrist = pose.wrist {
                let screenPoint = convertPoint(wrist.location)
                let radius: CGFloat = wrist.confidence > 0.7 ? 8 : 5
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: screenPoint.x - radius,
                        y: screenPoint.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(.red.opacity(Double(wrist.confidence)))
                )
            }
            
            // Draw elbow
            if let elbow = pose.elbow {
                let screenPoint = convertPoint(elbow.location)
                let radius: CGFloat = elbow.confidence > 0.7 ? 8 : 5
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: screenPoint.x - radius,
                        y: screenPoint.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(.orange.opacity(Double(elbow.confidence)))
                )
            }
            
            // Draw shoulder
            if let shoulder = pose.shoulder {
                let screenPoint = convertPoint(shoulder.location)
                let radius: CGFloat = shoulder.confidence > 0.7 ? 8 : 5
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: screenPoint.x - radius,
                        y: screenPoint.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(.yellow.opacity(Double(shoulder.confidence)))
                )
            }
            
            // Draw hip
            if let hip = pose.hip {
                let screenPoint = convertPoint(hip.location)
                let radius: CGFloat = hip.confidence > 0.7 ? 8 : 5
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: screenPoint.x - radius,
                        y: screenPoint.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(.blue.opacity(Double(hip.confidence)))
                )
            }
        }
    }
}

// MARK: - Setup Instructions Overlay
struct SetupInstructions: View {
    let isRecording: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if !isRecording {
                VStack(spacing: 10) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("Setup Instructions")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(icon: "1.circle.fill", text: "Stand 6-10 feet from camera")
                        InstructionRow(icon: "2.circle.fill", text: "Ensure full body is visible")
                        InstructionRow(icon: "3.circle.fill", text: "Good lighting on your body")
                        InstructionRow(icon: "4.circle.fill", text: "Clear space for swinging")
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
            }
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }
}

// MARK: - Stats Display
struct StatsDisplay: View {
    let totalShots: Int
    let successfulShots: Int
    let forehandCount: Int
    let backhandCount: Int
    let serveCount: Int
    
    var successRate: Int {
        guard totalShots > 0 else { return 0 }
        return Int((Double(successfulShots) / Double(totalShots)) * 100)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            // Main stats
            HStack {
                Image(systemName: "sportscourt")
                Text("Shots: \(totalShots)")
                    .bold()
            }
            
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Success: \(successRate)%")
            }
            
            Divider()
                .background(Color.white)
            
            // Shot breakdown
            if totalShots > 0 {
                HStack {
                    Image(systemName: "arrow.right.circle")
                    Text("FH: \(forehandCount)")
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "arrow.left.circle")
                    Text("BH: \(backhandCount)")
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "arrow.up.circle")
                    Text("Serve: \(serveCount)")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(10)
    }
}

// MARK: - Camera View
struct CameraView: View {
    @Binding var sessionData: SessionData?
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingInstructions = true
    
    var body: some View {
        ZStack {
            // Camera preview
            if viewModel.isSessionRunning {
                GeometryReader { geometry in
                    CameraPreview(session: viewModel.captureSession)
                        .ignoresSafeArea()
                        .overlay(
                            // Pose skeleton overlay
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
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Loading Camera...")
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    )
            }
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Exit")
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Stats display
                    StatsDisplay(
                        totalShots: viewModel.totalShots,
                        successfulShots: viewModel.successfulShots,
                        forehandCount: viewModel.forehandCount,
                        backhandCount: viewModel.backhandCount,
                        serveCount: viewModel.serveCount
                    )
                    .padding()
                }
                
                // Setup instructions (show when not recording)
                if !viewModel.isRecording && showingInstructions {
                    SetupInstructions(isRecording: viewModel.isRecording)
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation {
                                showingInstructions = false
                            }
                        }
                }
                
                Spacer()
                
                // Debug/feedback area
                if !viewModel.debugInfo.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(viewModel.debugInfo)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.8))
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Recording controls
                VStack(spacing: 20) {
                    // Recording indicator
                    if viewModel.isRecording {
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
                                            value: viewModel.isRecording
                                        )
                                )
                            Text("RECORDING")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    
                    // Record button
                    Button(action: {
                        if viewModel.isRecording {
                            sessionData = viewModel.stopRecording()
                            dismiss()
                        } else {
                            withAnimation {
                                showingInstructions = false
                            }
                            viewModel.startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? Color.red : Color.white)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            
                            if viewModel.isRecording {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white)
                                    .frame(width: 25, height: 25)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .disabled(!viewModel.isSessionRunning)
                    .opacity(viewModel.isSessionRunning ? 1 : 0.5)
                    
                    // Helper text
                    Text(viewModel.isRecording ? "Tap to finish session" : "Tap to start tracking")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(15)
                }
                .padding(.bottom, 30)
            }
            
            // Error display
            if let error = viewModel.cameraError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    
                    Text("Camera Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.black.opacity(0.9))
                .cornerRadius(15)
            }
        }
        .onAppear {
            viewModel.checkPermissions()
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        guard let session = session else {
            return view
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)
        
        // Store the preview layer for updates
        view.layer.setValue(previewLayer, forKey: "previewLayer")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.value(forKey: "previewLayer") as? AVCaptureVideoPreviewLayer else {
            return
        }
        
        // Update the frame
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}
