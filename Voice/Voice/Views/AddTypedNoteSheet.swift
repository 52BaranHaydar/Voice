import SwiftUI

public struct AddTypedNoteSheet: View {
    @Binding public var voiceNotes: [VoiceNote]
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var contentText: String = ""
    @State private var selectedCategory: NoteCategory = .general
    @State private var generateAiSummary: Bool = true
    @State private var isProcessingAi: Bool = false
    
    @State private var aiManager = VoiceAiManager()
    
    public init(voiceNotes: Binding<[VoiceNote]>) {
        self._voiceNotes = voiceNotes
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                VoiceTheme.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Not Başlığı")
                                .font(.caption.bold())
                                .foregroundColor(VoiceTheme.textSecondary)
                            TextField("Örn: Yazılım Mimarisi Notları...", text: $title)
                                .padding()
                                .background(VoiceTheme.bgCard)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        // Category Selector Chips
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kategori")
                                .font(.caption.bold())
                                .foregroundColor(VoiceTheme.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(NoteCategory.allCases) { category in
                                        Button(action: { selectedCategory = category }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: category.iconName)
                                                Text(category.rawValue)
                                            }
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == category ? VoiceTheme.primaryGlow : VoiceTheme.bgCard)
                                            .foregroundColor(.white)
                                            .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Note Body Editor
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Not İçeriği (Metin)")
                                    .font(.caption.bold())
                                    .foregroundColor(VoiceTheme.textSecondary)
                                Spacer()
                                Text("\(contentText.count) karakter")
                                    .font(.caption2)
                                    .foregroundColor(VoiceTheme.textSecondary)
                            }
                            
                            TextEditor(text: $contentText)
                                .frame(minHeight: 180)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(VoiceTheme.bgCard)
                                .cornerRadius(12)
                                .foregroundColor(VoiceTheme.textPrimary)
                        }
                        
                        // AI Summary Toggle
                        Toggle(isOn: $generateAiSummary) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(VoiceTheme.accentPink)
                                VStack(alignment: .leading) {
                                    Text("AI Akıllı Özet & Aksiyon Çıkar")
                                        .font(.subheadline.bold())
                                        .foregroundColor(VoiceTheme.textPrimary)
                                    Text("Otomatik özet ve yapılacaklar maddeleri oluşturur")
                                        .font(.caption2)
                                        .foregroundColor(VoiceTheme.textSecondary)
                                }
                            }
                        }
                        .tint(VoiceTheme.accentCyan)
                        .glassCardStyle()
                        
                        if isProcessingAi {
                            HStack {
                                ProgressView().tint(VoiceTheme.accentCyan)
                                Text("AI özet hazırlanıyor...")
                                    .font(.subheadline)
                                    .foregroundColor(VoiceTheme.accentCyan)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Save Button
                        Button(action: saveTypedNote) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                Text("Yazılı Notu Kaydet")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(VoiceTheme.recordButtonGradient)
                            .cornerRadius(16)
                            .shadow(color: VoiceTheme.primaryGlow.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                        .disabled(contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessingAi)
                        .opacity(contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    }
                    .padding()
                }
            }
            .navigationTitle("Yazılı Not Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(VoiceTheme.textSecondary)
                }
            }
        }
    }
    
    private func saveTypedNote() {
        let finalTitle = title.isEmpty ? "Yazılı Not \(voiceNotes.count + 1)" : title
        let bodyText = contentText
        
        if generateAiSummary {
            isProcessingAi = true
            Task {
                let (summary, actions) = await aiManager.summarizeTranscription(bodyText)
                
                let newNote = VoiceNote(
                    title: finalTitle,
                    category: selectedCategory,
                    audioFileName: "",
                    duration: Double(bodyText.count) / 15.0, // Simulated reading duration
                    createdAt: Date(),
                    transcript: bodyText,
                    aiSummary: summary,
                    actionItems: actions,
                    isFavorite: false,
                    audioLevels: [0.3, 0.5, 0.7, 0.4, 0.6, 0.8, 0.5]
                )
                
                DispatchQueue.main.async {
                    self.voiceNotes.insert(newNote, at: 0)
                    self.isProcessingAi = false
                    self.dismiss()
                }
            }
        } else {
            let newNote = VoiceNote(
                title: finalTitle,
                category: selectedCategory,
                audioFileName: "",
                duration: Double(bodyText.count) / 15.0,
                createdAt: Date(),
                transcript: bodyText,
                aiSummary: "Yazılı not.",
                actionItems: [],
                isFavorite: false,
                audioLevels: [0.3, 0.5, 0.4]
            )
            voiceNotes.insert(newNote, at: 0)
            dismiss()
        }
    }
}
