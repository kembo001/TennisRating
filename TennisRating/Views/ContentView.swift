import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var showCalibration = false
    @State private var sessionData: SessionData?
    @StateObject private var calibrationData = SwingCalibrationData()
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            // Handle authentication state
            switch authManager.authState {
            case .loading:
                LoadingView()
                
            case .unauthenticated:
                AuthenticationView()
                
            case .authenticated(let user):
                authenticatedContent(user: user)
            }
        }
        .sheet(item: $sessionData) { data in
            ResultsView(sessionData: data)
        }
    }
    
    @ViewBuilder
    private func authenticatedContent(user: User) -> some View {
        TabView(selection: $selectedTab) {
            // Practice Tab
            practiceView
                .tabItem {
                    Image(systemName: "figure.tennis")
                    Text("Practice")
                }
                .tag(0)
            
            // History Tab (placeholder for Priority #4)
            sessionHistoryView
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("History")
                }
                .tag(1)
            
            // Stats Tab (placeholder for Priority #5)
            statsView
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Stats")
                }
                .tag(2)
            
            // Profile Tab
            profileView
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(3)
        }
    }
    
    // MARK: - Practice View (Your existing main content)
    private var practiceView: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with user greeting
                VStack(spacing: 10) {
                    if let user = authManager.currentUser {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Hello, \(user.name.components(separatedBy: " ").first ?? "Player")!")
                                    .font(.title2)
                                    .bold()
                                
                                Text("Ready for practice?")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Demo mode indicator
                            if authManager.useMockData {
                                VStack {
                                    Image(systemName: "wrench.and.screwdriver")
                                        .foregroundColor(.orange)
                                    Text("Demo")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Text("AI-Powered Swing Detection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
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
            .navigationTitle("Tennis Practice")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
    
    // History Tab - Now with real functionality
    private var sessionHistoryView: some View {
        SessionHistoryView()
    }
    
    private var statsView: some View {
        StatisticsDashboardView()
    }
    
    private var profileView: some View {
        NavigationView {
            UserProfileView()
        }
    }
}

// Keep your existing TipRow and CameraViewWithCalibration components
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
