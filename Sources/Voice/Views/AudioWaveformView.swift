import SwiftUI

public struct AudioWaveformView: View {
    public var levels: [Float]
    public var isRecording: Bool
    public var barColor: Color = VoiceTheme.accentCyan
    public var maxBars: Int = 24
    
    public init(levels: [Float], isRecording: Bool = false, barColor: Color = VoiceTheme.accentCyan, maxBars: Int = 24) {
        self.levels = levels
        self.isRecording = isRecording
        self.barColor = barColor
        self.maxBars = maxBars
    }
    
    private var displayLevels: [Float] {
        guard !levels.isEmpty else { return [] }
        if levels.count <= maxBars {
            return levels
        }
        if isRecording {
            return Array(levels.suffix(maxBars))
        } else {
            let step = Double(levels.count) / Double(maxBars)
            return (0..<maxBars).map { i in
                let index = Int(Double(i) * step)
                return levels[min(index, levels.count - 1)]
            }
        }
    }
    
    public var body: some View {
        let currentLevels = displayLevels
        GeometryReader { geometry in
            let maxHeight = geometry.size.height > 0 ? geometry.size.height : 40
            HStack(spacing: 4) {
                if currentLevels.isEmpty {
                    ForEach(0..<maxBars, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor.opacity(0.3))
                            .frame(width: 4, height: isRecording ? CGFloat.random(in: 8...(maxHeight * 0.8)) : 8)
                            .animation(isRecording ? .easeInOut(duration: 0.25).repeatForever().delay(Double(i) * 0.03) : .default, value: isRecording)
                    }
                } else {
                    ForEach(0..<currentLevels.count, id: \.self) { index in
                        let level = CGFloat(currentLevels[index])
                        let barHeight = max(6, min(maxHeight, level * maxHeight))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [barColor, VoiceTheme.primaryGlow],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 4, height: barHeight)
                            .shadow(color: barColor.opacity(0.5), radius: 2, x: 0, y: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
