import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var sessionData: SessionData?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Tennis Shot Tracker")
                    .font(.largeTitle)
                    .bold()
                
                Text("Track your forehand practice")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showCamera = true
                }) {
                    Label("Start Practice", systemImage: "camera.fill")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .sheet(isPresented: $showCamera) {
                CameraView(sessionData: $sessionData)
            }
            .sheet(item: $sessionData) { data in
                ResultsView(sessionData: data)
            }
        }
    }
}
