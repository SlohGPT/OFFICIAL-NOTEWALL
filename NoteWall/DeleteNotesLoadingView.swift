import SwiftUI
import AudioToolbox

/// Loading overlay for delete operations - shows 10 second animation then success
struct DeleteNotesLoadingView: View {
    @Binding var isPresented: Bool
    
    @State private var showSuccess: Bool = false
    @State private var timer: Timer?
    @State private var startTime: Date = Date()
    
    // Animation states
    @State private var progressRotation: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var progress: Double = 0.0
    @State private var remainingSeconds: Int = 10
    
    private let expectedDuration: TimeInterval = 10.0
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping outside
                }
            
            if showSuccess {
                successView
                    .transition(.scale.combined(with: .opacity))
            } else {
                loadingView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startLoading()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 22) {
                ZStack {
                    // Outer subtle glow
                    Circle()
                        .fill(Color("AppAccent").opacity(0.08))
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulseScale)
                    
                    // Background track
                    Circle()
                        .stroke(Color("AppAccent").opacity(0.15), lineWidth: 5)
                        .frame(width: 76, height: 76)
                    
                    // Progress circle that fills up
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color("AppAccent"),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90)) // Start from top
                        .shadow(color: Color("AppAccent").opacity(0.4), radius: 6, x: 0, y: 2)
                    
                    // Countdown number in center
                    VStack(spacing: 2) {
                        Text("\(remainingSeconds)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("sec")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status text
                Text("Deleting notes...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 48)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
            .padding(32)
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(Color("AppAccent").opacity(0.12))
                    .frame(width: 72, height: 72)
                    .blur(radius: 10)
                
                // Success circle background
                Circle()
                    .fill(Color("AppAccent"))
                    .frame(width: 64, height: 64)
                    .shadow(color: Color("AppAccent").opacity(0.3), radius: 12, x: 0, y: 6)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }
            
            Text("Notes Deleted!")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 12)
        )
        .padding(32)
        .onAppear {
            animateSuccess()
        }
    }
    
    // MARK: - Timer & Loading Management
    
    private func startLoading() {
        startTime = Date()
        
        // Subtle breathing pulse effect
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.12
        }
        
        // Smooth progress animation from 0 to 1 over expected duration
        withAnimation(.linear(duration: expectedDuration)) {
            progress = 1.0
        }
        
        // Timer to update countdown
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, expectedDuration - elapsed)
            remainingSeconds = Int(ceil(remaining))
            
            // Show success after expected duration
            if elapsed >= expectedDuration && !showSuccess {
                handleSuccess()
            }
        }
    }
    
    func handleSuccess() {
        guard !showSuccess else { return }
        
        cleanup()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showSuccess = true
        }
        
        // Auto-dismiss after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateSuccess() {
        // Play success sound
        AudioServicesPlaySystemSound(1519) // Success sound
        
        // Medium impact haptic
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        
        // Animate checkmark with smooth spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        
        // Stop any ongoing animations
        withAnimation(.none) {
            pulseScale = 1.0
        }
    }
}

