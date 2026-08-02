import SwiftUI

public struct VoiceTheme {
    public static let bgDark = Color(red: 0.05, green: 0.05, blue: 0.08)
    public static let bgCard = Color(red: 0.10, green: 0.11, blue: 0.16)
    public static let bgCardBorder = Color(red: 0.20, green: 0.22, blue: 0.32)
    
    public static let primaryGlow = Color(red: 0.52, green: 0.35, blue: 0.98)
    public static let accentCyan = Color(red: 0.22, green: 0.85, blue: 0.96)
    public static let accentPink = Color(red: 0.98, green: 0.35, blue: 0.65)
    
    public static let textPrimary = Color.white
    public static let textSecondary = Color(red: 0.68, green: 0.70, blue: 0.78)
    
    public static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.04, blue: 0.09), Color(red: 0.08, green: 0.06, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    public static var recordButtonGradient: LinearGradient {
        LinearGradient(
            colors: [primaryGlow, accentPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public extension View {
    func glassCardStyle() -> some View {
        self
            .padding()
            .background(VoiceTheme.bgCard.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VoiceTheme.bgCardBorder.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}
