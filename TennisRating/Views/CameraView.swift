import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var sessionData: SessionData?
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Camera preview
            if viewModel.isSessionRunning {
                CameraPreview(session: viewModel.captureSession)
                    .ignoresSafeArea()
            } else {
                // Debug background when camera not running
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
            
            // Error display
            if let error = viewModel.cameraError {
                VStack {
                    Text("Camera Error:")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .background(Color.red.opacity(0.8))
                .cornerRadius(10)
                .padding()
            }
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .padding()
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Shot counter
                    VStack(alignment: .trailing) {
                        Text("Shots: \(viewModel.totalShots)")
                        Text("Success: \(viewModel.successfulShots)")
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                }
                
                Spacer()
                
                // Court boundary guide (only show when recording)
                if viewModel.isRecording {
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 300, height: 200)
                        .opacity(0.5)
                        .overlay(
                            Text("Aim camera at court")
                                .foregroundColor(.yellow)
                                .padding(.top, -30)
                        )
                }
                
                Spacer()
                
                // Debug info
                VStack {
                    Text("Session Running: \(viewModel.isSessionRunning ? "Yes" : "No")")
                        .foregroundColor(.yellow)
                    Text("Recording: \(viewModel.isRecording ? "Yes" : "No")")
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                
                // Record button
                Button(action: {
                    if viewModel.isRecording {
                        sessionData = viewModel.stopRecording()
                        dismiss()
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.white)
                            .frame(width: 70, height: 70)
                        
                        if viewModel.isRecording {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .cornerRadius(5)
                        }
                    }
                }
                .padding(.bottom, 30)
                .disabled(!viewModel.isSessionRunning)
                .opacity(viewModel.isSessionRunning ? 1 : 0.5)
            }
        }
        .onAppear {
            print("CameraView: Appeared")
            viewModel.checkPermissions()
        }
    }
}

// Camera Preview UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        print("CameraPreview: Making UIView")
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        guard let session = session else {
            print("CameraPreview: No session provided")
            return view
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)
        
        // Store the preview layer for updates
        view.layer.setValue(previewLayer, forKey: "previewLayer")
        
        print("CameraPreview: Preview layer created")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.value(forKey: "previewLayer") as? AVCaptureVideoPreviewLayer else {
            print("CameraPreview: No preview layer found in update")
            return
        }
        
        // Update the frame
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}
