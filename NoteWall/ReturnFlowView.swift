import SwiftUI

struct ReturnFlowView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int

    @AppStorage(AppStorageKeys.troubleshootingReturnFlow) private var isTroubleshootingReturnFlow = false
    @State private var hasStartedReturnSetup = false

    var body: some View {
        Group {
            if hasStartedReturnSetup {
                OnboardingView(
                    isPresented: $isPresented,
                    onboardingVersion: onboardingVersion,
                    isReturnFlow: true
                )
            } else {
                introView
            }
        }
        .onAppear {
            isTroubleshootingReturnFlow = true
        }
        .onDisappear {
            if !isPresented {
                isTroubleshootingReturnFlow = false
            }
        }
    }

    private var introView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.18))
                        .frame(width: 108, height: 108)

                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.appAccent)
                }

                VStack(spacing: 12) {
                    Text("Quick Return Flow")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Don’t worry, you already saw this. We know — this is just the shortcut setup part so you can reinstall and get back to using NoteWall.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()

                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasStartedReturnSetup = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    ReturnFlowView(isPresented: .constant(true), onboardingVersion: 3)
}
