import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var showCalibration = false
    @State private var sessionData: SessionData?
    @StateObject private var calibrationData = SwingCalibrationData()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Text("Tennis Shot Tracker")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("AI-Powered Swing Detection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Calibration status
                if calibrationData.hasCalibration() {
                    VStack(spacing: 5) {
                        Label("Calibration Active", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(calibrationData.calibrationSummary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Main action buttons
                VStack(spacing: 15) {
                    // Start Practice button
                    Button(action: {
                        showCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Start Practice")
                                .font(.title2)
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    
                    // Calibration button
                    Button(action: {
                        showCalibration = true
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calibration Mode")
                                    .font(.headline)
                                Text("Train the AI to recognize your swings")
                                    .font(.caption)
                                    .opacity(0.9)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    
                    // Clear calibration button (if calibration exists)
                    if calibrationData.hasCalibration() {
                        Button(action: {
                            calibrationData.clearCalibration()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Calibration")
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.top, 5)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Tips section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Tips")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TipRow(icon: "1.circle", text: "Calibrate first for best accuracy")
                        TipRow(icon: "2.circle", text: "Stand 6-10 feet from camera")
                        TipRow(icon: "3.circle", text: "Ensure good lighting")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showCamera) {
                CameraViewWithCalibration(
                    sessionData: $sessionData,
                    calibrationData: calibrationData
                )
            }
            .sheet(isPresented: $showCalibration) {
                CalibrationCameraView(
                    calibrationData: calibrationData,
                    sessionData: $sessionData
                )
            }
            .sheet(item: $sessionData) { data in
                ResultsView(sessionData: data)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Wrapper view to pass calibration data to regular camera
struct CameraViewWithCalibration: View {
    @Binding var sessionData: SessionData?
    let calibrationData: SwingCalibrationData
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        CameraView(sessionData: $sessionData)
            .onAppear {
                viewModel.setCalibrationData(calibrationData)
            }
    }
}
