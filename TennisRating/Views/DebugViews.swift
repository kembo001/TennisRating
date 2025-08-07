import SwiftUI

// MARK: - Debug Overlay View
struct DebugOverlay: View {
    let debugInfo: EnhancedSwingDetector.DebugInfo?
    @State private var showDebug = true
    
    var body: some View {
        VStack {
            // Toggle button
            HStack {
                Spacer()
                toggleButton
            }
            
            if showDebug, let info = debugInfo {
                debugPanel(info: info)
            }
            
            Spacer()
        }
    }
    
    private var toggleButton: some View {
        Button(action: { showDebug.toggle() }) {
            Image(systemName: showDebug ? "eye.slash" : "eye")
                .padding(10)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .clipShape(Circle())
        }
        .padding()
    }
    
    private func debugPanel(info: EnhancedSwingDetector.DebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            debugHeader
            
            // Metrics
            speedMetric(info.wristSpeed)
            angleMetric(info.elbowAngle)
            rotationMetric(info.shoulderRotation)
            directionMetric(info.motionDirection)
            phaseMetric(info.swingPhase)
            
            // Confidence
            confidenceSection(info.confidence)
            
            // Thresholds
            thresholdSection(info: info)
        }
        .padding()
        .background(Color.black.opacity(0.85))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green, lineWidth: 1)
        )
        .padding()
    }
    
    private var debugHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG INFO")
                .font(.caption)
                .bold()
                .foregroundColor(.green)
            
            Divider().background(Color.green)
        }
    }
    
    private func speedMetric(_ speed: CGFloat) -> some View {
        HStack {
            Text("Wrist Speed:")
                .font(.caption)
            Text("\(Int(speed)) px/s")
                .font(.caption)
                .foregroundColor(speedColor(speed))
                .bold()
        }
    }
    
    private func angleMetric(_ angle: CGFloat) -> some View {
        HStack {
            Text("Elbow Angle:")
                .font(.caption)
            Text("\(Int(angle))°")
                .font(.caption)
                .foregroundColor(.cyan)
        }
    }
    
    private func rotationMetric(_ rotation: CGFloat) -> some View {
        HStack {
            Text("Shoulder Rot:")
                .font(.caption)
            Text("\(Int(rotation)) px")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    private func directionMetric(_ direction: String) -> some View {
        HStack {
            Text("Direction:")
                .font(.caption)
            HStack(spacing: 2) {
                Image(systemName: directionIcon(direction))
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text(direction)
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private func phaseMetric(_ phase: SwingPhase) -> some View {
        HStack {
            Text("Phase:")
                .font(.caption)
            Text(phaseString(phase))
                .font(.caption)
                .foregroundColor(phaseColor(phase))
                .bold()
        }
    }
    
    private func confidenceSection(_ confidence: Float) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Confidence: \(Int(confidence * 100))%")
                .font(.caption)
            
            GeometryReader { geometry in
                confidenceBar(confidence: confidence, width: geometry.size.width)
            }
            .frame(height: 4)
        }
    }
    
    private func confidenceBar(confidence: Float, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)
            
            Rectangle()
                .fill(confidenceColor(confidence))
                .frame(width: width * CGFloat(confidence), height: 4)
        }
    }
    
    private func thresholdSection(info: EnhancedSwingDetector.DebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THRESHOLDS")
                .font(.caption2)
                .foregroundColor(.gray)
            
            ThresholdIndicator(
                label: "Min Speed",
                value: info.wristSpeed,
                threshold: 150,
                met: info.wristSpeed > 150
            )
            
            ThresholdIndicator(
                label: "Confidence",
                value: CGFloat(info.confidence) * 100,
                threshold: 50,
                met: info.confidence > 0.5
            )
        }
    }
    
    // Helper functions
    private func speedColor(_ speed: CGFloat) -> Color {
        if speed < 50 { return .gray }
        if speed < 150 { return .yellow }
        if speed < 300 { return .orange }
        return .red
    }
    
    private func phaseColor(_ phase: SwingPhase) -> Color {
        switch phase {
        case .idle: return .gray
        case .backswing: return .yellow
        case .forward: return .orange
        case .followThrough: return .green
        case .completed: return .blue
        }
    }
    
    private func phaseString(_ phase: SwingPhase) -> String {
        switch phase {
        case .idle: return "IDLE"
        case .backswing: return "BACKSWING"
        case .forward: return "FORWARD"
        case .followThrough: return "FOLLOW"
        case .completed: return "COMPLETE"
        }
    }
    
    private func directionIcon(_ direction: String) -> String {
        switch direction {
        case "up": return "arrow.up"
        case "down": return "arrow.down"
        case "left": return "arrow.left"
        case "right": return "arrow.right"
        default: return "minus"
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence < 0.3 { return .red }
        if confidence < 0.6 { return .yellow }
        return .green
    }
}

// MARK: - Threshold Indicator
struct ThresholdIndicator: View {
    let label: String
    let value: CGFloat
    let threshold: CGFloat
    let met: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(met ? .green : .red)
                .font(.caption2)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text("\(Int(value))/\(Int(threshold))")
                .font(.caption2)
                .foregroundColor(met ? .green : .red)
        }
    }
}

// MARK: - Wrist Path Visualization
struct WristPathOverlay: View {
    let path: [CGPoint]
    let geometrySize: CGSize
    
    var body: some View {
        Canvas { context, size in
            guard path.count > 1 else { return }
            
            drawPath(context: context, size: size)
            drawKeyPoints(context: context, size: size)
        }
    }
    
    private func drawPath(context: GraphicsContext, size: CGSize) {
        // Convert normalized points to screen coordinates
        let screenPath = path.map { point in
            CGPoint(
                x: point.x * size.width,
                y: (1 - point.y) * size.height
            )
        }
        
        // Create path
        var pathLine = Path()
        pathLine.move(to: screenPath[0])
        
        for i in 1..<screenPath.count {
            pathLine.addLine(to: screenPath[i])
        }
        
        // Draw with gradient
        let gradient = Gradient(colors: [
            Color.cyan.opacity(0.2),
            Color.cyan.opacity(0.8)
        ])
        
        context.stroke(
            pathLine,
            with: .linearGradient(
                gradient,
                startPoint: screenPath.first ?? .zero,
                endPoint: screenPath.last ?? .zero
            ),
            lineWidth: 3
        )
    }
    
    private func drawKeyPoints(context: GraphicsContext, size: CGSize) {
        guard path.count > 1 else { return }
        
        // Convert first and last points
        let firstPoint = CGPoint(
            x: path.first!.x * size.width,
            y: (1 - path.first!.y) * size.height
        )
        
        let lastPoint = CGPoint(
            x: path.last!.x * size.width,
            y: (1 - path.last!.y) * size.height
        )
        
        // Draw start point (green)
        context.fill(
            Circle().path(in: CGRect(
                x: firstPoint.x - 5,
                y: firstPoint.y - 5,
                width: 10,
                height: 10
            )),
            with: .color(.green)
        )
        
        // Draw end point (red)
        context.fill(
            Circle().path(in: CGRect(
                x: lastPoint.x - 5,
                y: lastPoint.y - 5,
                width: 10,
                height: 10
            )),
            with: .color(.red)
        )
    }
}
