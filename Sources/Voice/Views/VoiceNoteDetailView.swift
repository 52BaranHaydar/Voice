import SwiftUI

@MainActor
public struct VoiceNoteDetailView: View {
    @Binding public var note: VoiceNote
    public var playerManager: AudioPlayerManager
    public var ttsManager: TextToSpeechManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSpeedIndex: Int = 1
    @State private var isCopied: Bool = false
    private let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]
    
    public init(note: Binding<VoiceNote>, playerManager: AudioPlayerManager, ttsManager: TextToSpeechManager) {
        self._note = note
        self.playerManager = playerManager
        self.ttsManager = ttsManager
    }
    
    public var body: some View {
        ZStack {
            // Background Gradient & Ambient Glow Blobs
            VoiceTheme.backgroundGradient.ignoresSafeArea()
            
            ZStack {
                Circle()
                    .fill(VoiceTheme.primaryGlow.opacity(0.14))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: -100, y: -160)
                
                Circle()
                    .fill(VoiceTheme.accentCyan.opacity(0.12))
                    .frame(width: 260, height: 260)
                    .blur(radius: 50)
                    .offset(x: 120, y: 140)
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Bar (Close & Favorite)
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(VoiceTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(VoiceTheme.bgCard.opacity(0.8))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(VoiceTheme.bgCardBorder.opacity(0.5), lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                        
                        Button(action: { note.isFavorite.toggle() }) {
                            Image(systemName: note.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(note.isFavorite ? .yellow : VoiceTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(VoiceTheme.bgCard.opacity(0.8))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(note.isFavorite ? Color.yellow.opacity(0.5) : VoiceTheme.bgCardBorder.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Title & Metadata Hero Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: note.category.iconName)
                                    .font(.caption2)
                                Text(note.category.rawValue)
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(VoiceTheme.primaryGlow.opacity(0.3))
                            .foregroundColor(VoiceTheme.accentCyan)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(VoiceTheme.accentCyan.opacity(0.4), lineWidth: 1)
                            )
                            
                            Text(note.formattedDate)
                                .font(.caption.monospaced())
                                .foregroundColor(VoiceTheme.textSecondary)
                        }
                        
                        TextField("Not Başlığı", text: $note.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(VoiceTheme.textPrimary)
                    }
                    .padding(.horizontal, 4)
                    
                    // Concentrated Audio / Player Card
                    VStack(spacing: 16) {
                        AudioWaveformView(levels: note.audioLevels, isRecording: false, barColor: VoiceTheme.primaryGlow)
                            .frame(height: 45)
                            .padding(.horizontal, 8)
                        
                        if !note.audioFileName.isEmpty {
                            VStack(spacing: 6) {
                                Slider(
                                    value: Binding(
                                        get: { playerManager.currentTime },
                                        set: { playerManager.seek(to: $0) }
                                    ),
                                    in: 0...max(1.0, playerManager.duration)
                                )
                                .tint(VoiceTheme.accentCyan)
                                
                                HStack {
                                    Text(formatTime(playerManager.currentTime))
                                    Spacer()
                                    Text(note.formattedDuration)
                                }
                                .font(.caption.monospaced())
                                .foregroundColor(VoiceTheme.textSecondary)
                            }
                            
                            HStack(spacing: 20) {
                                Button(action: cycleSpeed) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "gauge.with.dots.needle.50percent")
                                            .font(.caption2)
                                        Text("\(String(format: "%.1fx", speeds[selectedSpeedIndex]))")
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(VoiceTheme.bgCard)
                                    .foregroundColor(VoiceTheme.accentCyan)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(VoiceTheme.accentCyan.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if playerManager.isPlaying {
                                        playerManager.pauseAudio()
                                    } else {
                                        playerManager.playAudio(fileName: note.audioFileName)
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(VoiceTheme.recordButtonGradient)
                                            .frame(width: 56, height: 56)
                                            .shadow(color: VoiceTheme.primaryGlow.opacity(0.5), radius: 10, x: 0, y: 4)
                                        
                                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(BouncyButtonStyle())
                                
                                Spacer()
                                
                                Button(action: shareTranscript) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(VoiceTheme.textPrimary)
                                        .frame(width: 40, height: 40)
                                        .background(VoiceTheme.bgCard)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(VoiceTheme.bgCardBorder.opacity(0.5), lineWidth: 1)
                                        )
                                }
                            }
                        } else {
                            // Written Note TTS Controls
                            HStack(spacing: 16) {
                                Button(action: {
                                    if ttsManager.isSpeaking {
                                        ttsManager.stopSpeaking()
                                    } else {
                                        ttsManager.speak(text: note.transcript)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : (note.category == .song ? "music.note" : "speaker.wave.2.fill"))
                                            .font(.headline)
                                        Text(ttsManager.isSpeaking ? "Durdur" : (note.category == .song ? "🎵 Şarkı Sözünü Dinle" : "Metni Sesli Dinle"))
                                            .font(.headline.bold())
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(VoiceTheme.recordButtonGradient)
                                    .cornerRadius(16)
                                    .shadow(color: VoiceTheme.primaryGlow.opacity(0.4), radius: 8, x: 0, y: 3)
                                }
                                
                                Button(action: shareTranscript) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(VoiceTheme.textPrimary)
                                        .frame(width: 46, height: 46)
                                        .background(VoiceTheme.bgCard)
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(VoiceTheme.bgCardBorder.opacity(0.5), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .glassCardStyle()
                    
                    // AI Akıllı Özet & Aksiyon Maddeleri / Şarkı Beste Card
                    if !note.aiSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: note.category == .song ? "music.note" : "sparkles")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(VoiceTheme.accentPink)
                                Text(note.category == .song ? "AI Şarkı & Beste Kartı" : "AI Akıllı Özet")
                                    .font(.headline.bold())
                                    .foregroundColor(VoiceTheme.textPrimary)
                            }
                            
                            Text(note.aiSummary)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .foregroundColor(VoiceTheme.textSecondary)
                            
                            if !note.actionItems.isEmpty {
                                Divider()
                                    .background(VoiceTheme.bgCardBorder.opacity(0.5))
                                
                                Text(note.category == .song ? "🎵 Ritim & Vokal Önerileri" : "Aksiyon Maddeleri")
                                    .font(.caption.bold())
                                    .foregroundColor(note.category == .song ? VoiceTheme.accentPink : VoiceTheme.accentCyan)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(note.actionItems, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: note.category == .song ? "music.note" : "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundColor(note.category == .song ? VoiceTheme.accentPink : VoiceTheme.accentCyan)
                                                .padding(.top, 2)
                                            Text(item.replacingOccurrences(of: "• ", with: ""))
                                                .font(.subheadline)
                                                .foregroundColor(VoiceTheme.textPrimary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(VoiceTheme.accentCyan.opacity(0.08))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(VoiceTheme.accentCyan.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .glassCardStyle()
                    }
                    
                    // Metin İçeriği (Editable Transcript) Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption)
                                    .foregroundColor(VoiceTheme.accentCyan)
                                Text("Metin İçeriği (Düzenlenebilir)")
                                    .font(.headline.bold())
                                    .foregroundColor(VoiceTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    if ttsManager.isSpeaking {
                                        ttsManager.stopSpeaking()
                                    } else {
                                        ttsManager.speak(text: note.transcript)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                            .font(.caption)
                                        Text(ttsManager.isSpeaking ? "Durdur" : "Sesli Okut")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(ttsManager.isSpeaking ? VoiceTheme.accentPink : VoiceTheme.primaryGlow)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background((ttsManager.isSpeaking ? VoiceTheme.accentPink : VoiceTheme.primaryGlow).opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: copyToClipboard) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                            .font(.caption)
                                        Text(isCopied ? "Kopyalandı" : "Kopyala")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(isCopied ? Color.green : VoiceTheme.accentCyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background((isCopied ? Color.green : VoiceTheme.accentCyan).opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        TextEditor(text: $note.transcript)
                            .frame(minHeight: 140)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(VoiceTheme.bgCard)
                            .cornerRadius(14)
                            .foregroundColor(VoiceTheme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(VoiceTheme.bgCardBorder.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .glassCardStyle()
                }
                .padding()
            }
        }
    }
    
    private func cycleSpeed() {
        selectedSpeedIndex = (selectedSpeedIndex + 1) % speeds.count
        playerManager.setPlaybackRate(speeds[selectedSpeedIndex])
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = note.transcript
        #endif
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
    
    private func shareTranscript() {
        let content = """
        📌 \(note.title)
        📅 Tarih: \(note.formattedDate)
        
        📝 Metin İçeriği:
        \(note.transcript)
        
        🤖 AI Özeti:
        \(note.aiSummary)
        """
        
        print("Share Content:\n\(content)")
    }
}
