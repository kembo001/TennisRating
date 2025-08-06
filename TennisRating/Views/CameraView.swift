import SwiftUI
import AVFoundation

// MARK: - Court Overlay
/// A visual guide that draws a tennis court outline over the camera preview.
/// The overlay changes color based on whether recording is active and shows
/// setup instructions when the session is idle.
struct CourtOverlay: View {
    let isRecording: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Court outline & lines
                Path { path in
                    let width = geometry.size.width * 0.8
                    let height = geometry.size.height * 0.5
                    let x = (geometry.size.width - width) / 2
                    let y = (geometry.size.height - height) / 2

                    // Court rectangle
                    path.addRect(CGRect(x: x, y: y, width: width, height: height))

                    // Net line (horizontal center)
                    path.move(to: CGPoint(x: x, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: x + width, y: geometry.size.height / 2))

                    // Service boxes (vertical center lines)
                    let serviceBoxHeight = height / 4
                    path.move(to: CGPoint(x: geometry.size.width / 2, y: y + height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width / 2, y: y + height / 2 + serviceBoxHeight))

                    path.move(to: CGPoint(x: geometry.size.width / 2, y: y + height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width / 2, y: y + height / 2 - serviceBoxHeight))
                }
                .stroke(isRecording ? Color.green : Color.yellow, lineWidth: 2)
                .opacity(0.7)

                // Zone labels
                VStack {
                    Text("Opponent's Court")
                        .foregroundColor(.yellow)
                        .padding(.top, geometry.size.height * 0.3)

                    Spacer()

                    Text("Your Court")
                        .foregroundColor(.yellow)
                        .padding(.bottom, geometry.size.height * 0.2)
                }

                // Setup instructions (only when not recording)
                if !isRecording {
                    Text("Position camera to see full court")
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .position(x: geometry.size.width / 2, y: 50)
                }
            }
        }
    }
}

// MARK: - Camera View
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

                // Court overlay guide (always visible)
                CourtOverlay(isRecording: viewModel.isRecording)
                    .allowsHitTesting(false)

                Spacer()

                // Debug info
                VStack {
                    Text("Session Running: \(viewModel.isSessionRunning ? "Yes" : "No")")
                        .foregroundColor(.yellow)
                    Text("Recording: \(viewModel.isRecording ? "Yes" : "No")")
                        .foregroundColor(.yellow)
                    if !viewModel.debugInfo.isEmpty {
                        Text(viewModel.debugInfo)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
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

// MARK: - Camera Preview UIViewRepresentable
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
