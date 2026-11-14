import SwiftUI

public struct CaptchaWidgetView: View {
    public let isVerified: Bool
    public let isLoading: Bool
    public let onCheckboxTapped: () -> Void

    public init(isVerified: Bool, isLoading: Bool, onCheckboxTapped: @escaping () -> Void) {
        self.isVerified = isVerified
        self.isLoading = isLoading
        self.onCheckboxTapped = onCheckboxTapped
    }

    public var body: some View {
        Button(action: {
            if !isVerified && !isLoading {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onCheckboxTapped()
            }
        }) {
            HStack(spacing: 14) {
                // Checkbox Box
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isVerified ? PortColors.successGreen : PortColors.borderGlass,
                            lineWidth: 1.5
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isVerified ? PortColors.successGreen.opacity(0.18) : Color.black.opacity(0.40))
                        )
                        .frame(width: 26, height: 26)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.75)
                    } else if isVerified {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(PortColors.successGreen)
                    }
                }

                Text("Ich bin kein Roboter")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isVerified ? PortColors.textPrimary : PortColors.textSecondary)

                Spacer()

                // Right Side Captcha Branding
                VStack(spacing: 2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14))
                        .foregroundColor(PortColors.textMuted)

                    Text("CAPTCHA")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(PortColors.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PortColors.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isVerified ? PortColors.successGreen.opacity(0.45) : PortColors.borderGlass, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isVerified || isLoading)
    }
}
