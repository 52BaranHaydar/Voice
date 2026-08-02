import SwiftUI

@MainActor
public struct RecorderView: View {
    @Binding public var voiceNotes: [VoiceNote]
    @State private var recorderManager = AudioRecorderManager()
    @State private var speechManager = SpeechRecognizerManager()
    @State private var aiManager = VoiceAiManager()
    
    @State private var noteTitle: String = ""
    @State private var customTranscript: String = ""
    @State private var selectedCategory: NoteCategory = .general
    @State private var isPulseAnimating: Bool = false
    @State private var showSaveSheet: Bool = false
    @State private var showTypedNoteSheet: Bool = false
    @State private var isProcessingAi: Bool = false
    @State private var isTranscribing: Bool = false
    
    // Kaydedilen ses dosyası bilgileri (stopRecording sonrası saklanır)
    @State private var savedFileName: String = ""
    @State private var savedDuration: TimeInterval = 0
    @State private var savedLevels: [Float] = []
    
    public init(voiceNotes: Binding<[VoiceNote]>) {
        self._voiceNotes = voiceNotes
    }
    
    public var body: some View {
        ZStack {
            // Background Gradient & Ambient Glow Blobs
            VoiceTheme.backgroundGradient
                .ignoresSafeArea()
            
            // Glowing Ambient Light Orbs
            ZStack {
                Circle()
                    .fill(VoiceTheme.primaryGlow.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: -80, y: -140)
                
                Circle()
                    .fill(VoiceTheme.accentCyan.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 50)
                    .offset(x: 100, y: 100)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header & Manual Type Shortcut
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Voice Studio")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(VoiceTheme.textPrimary)
                            
                            if recorderManager.isRecording {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("REC")
                                        .font(.caption2.bold())
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }
                        
                        Text("Konuşun veya doğrudan yazarak not ekleyin")
                            .font(.subheadline)
                            .foregroundColor(VoiceTheme.textSecondary)
                    }
                    Spacer()
                    
                    Button(action: { showTypedNoteSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14, weight: .bold))
                            Text("Yazılı Not")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(VoiceTheme.accentCyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(VoiceTheme.bgCard.opacity(0.8))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VoiceTheme.accentCyan.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: VoiceTheme.accentCyan.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Quick Category Selector Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(NoteCategory.allCases) { category in
                            Button(action: { selectedCategory = category }) {
                                HStack(spacing: 6) {
                                    Image(systemName: category.iconName)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category
                                    ? VoiceTheme.primaryGlow
                                    : VoiceTheme.bgCard.opacity(0.6)
                                )
                                .foregroundColor(selectedCategory == category ? .white : VoiceTheme.textSecondary)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            selectedCategory == category
                                            ? VoiceTheme.accentCyan.opacity(0.6)
                                            : VoiceTheme.bgCardBorder.opacity(0.4),
                                            lineWidth: 1
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 10)
                
                // Hero Record Section
                ZStack {
                    // Pulsing Outer Aura Rings
                    if recorderManager.isRecording && !recorderManager.isPaused {
                        Circle()
                            .stroke(VoiceTheme.primaryGlow.opacity(0.35), lineWidth: 4)
                            .frame(width: 230, height: 230)
                            .scaleEffect(isPulseAnimating ? 1.3 : 0.95)
                            .opacity(isPulseAnimating ? 0.0 : 0.8)
                            .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: isPulseAnimating)
                        
                        Circle()
                            .stroke(VoiceTheme.accentPink.opacity(0.45), lineWidth: 3)
                            .frame(width: 180, height: 180)
                            .scaleEffect(isPulseAnimating ? 1.18 : 1.0)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulseAnimating)
                    } else {
                        // Ambient Breathing Ring when Idle
                        Circle()
                            .fill(VoiceTheme.primaryGlow.opacity(0.12))
                            .frame(width: 160, height: 160)
                            .shadow(color: VoiceTheme.primaryGlow.opacity(0.2), radius: 25)
                    }
                    
                    // Main Record Mic Button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(VoiceTheme.recordButtonGradient)
                                .frame(width: 130, height: 130)
                                .shadow(color: recorderManager.isRecording ? VoiceTheme.accentPink.opacity(0.7) : VoiceTheme.primaryGlow.opacity(0.6), radius: 25, x: 0, y: 10)
                            
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: recorderManager.isRecording ? (recorderManager.isPaused ? "play.fill" : "pause.fill") : "mic.fill")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                
                // Recording Status / Timer Display
                VStack(spacing: 6) {
                    if recorderManager.isRecording {
                        Text(recorderManager.formattedTime)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(VoiceTheme.accentCyan)
                            .shadow(color: VoiceTheme.accentCyan.opacity(0.5), radius: 10, x: 0, y: 0)
                        
                        Text(recorderManager.isPaused ? "Kayıt Duraklatıldı" : "Sesiniz Kaydediliyor...")
                            .font(.caption.bold())
                            .foregroundColor(VoiceTheme.textSecondary)
                    } else {
                        Text("Kayda Başlamak İçin Dokunun")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(VoiceTheme.textPrimary)
                        
                        Text("Yapay zeka ile anında metne ve özete dönüşsün")
                            .font(.caption)
                            .foregroundColor(VoiceTheme.textSecondary)
                    }
                }
                .padding(.top, 6)
                
                // Audio Waveform Visualizer
                AudioWaveformView(levels: recorderManager.liveAudioLevels, isRecording: recorderManager.isRecording)
                    .frame(height: 40)
                    .padding(.horizontal, 30)
                
                Spacer(minLength: 10)
                
                // Live Speech Stream Glass Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: selectedCategory == .song ? "music.note" : "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(selectedCategory == .song ? VoiceTheme.accentPink : VoiceTheme.accentCyan)
                            
                            Text(selectedCategory == .song ? "AI ŞARKI YAZARI MODU" : "CANLI METİN DÖKÜMÜ")
                                .font(.caption2.bold())
                                .foregroundColor(selectedCategory == .song ? VoiceTheme.accentPink : VoiceTheme.accentCyan)
                        }
                        
                        Spacer()
                        
                        if speechManager.isTranscribing {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(VoiceTheme.accentPink)
                                    .frame(width: 6, height: 6)
                                Text("Canlı İşleniyor")
                                    .font(.caption2.bold())
                                    .foregroundColor(VoiceTheme.accentPink)
                            }
                        }
                    }
                    
                    ScrollView {
                        Text(
                            recorderManager.isRecording && speechManager.liveTranscript.isEmpty
                                ? "🎙️ Konuşmaya başlayın — söyledikleriniz buraya gerçek zamanlı olarak yazılacak..."
                                : speechManager.liveTranscript.isEmpty
                                    ? "Kaydı başlatmak için mikrofona dokunun."
                                    : speechManager.liveTranscript
                        )
                        .font(.subheadline)
                        .lineSpacing(4)
                        .foregroundColor(speechManager.liveTranscript.isEmpty ? VoiceTheme.textSecondary : VoiceTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    }
                    .frame(height: 85)
                }
                .glassCardStyle()
                .padding(.horizontal, 20)
                
                // Controls Bar
                if recorderManager.isRecording {
                    HStack(spacing: 20) {
                        Button(action: cancelRecording) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                Text("İptal")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.75))
                            .cornerRadius(18)
                        }
                        
                        Button(action: finishRecordingAndPromptSave) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                Text("Kaydı Tamamla")
                                    .font(.headline.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(VoiceTheme.recordButtonGradient)
                            .cornerRadius(18)
                            .shadow(color: VoiceTheme.primaryGlow.opacity(0.5), radius: 12, x: 0, y: 4)
                        }
                    }
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Spacer().frame(height: 10)
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            saveNoteSheet
        }
        .sheet(isPresented: $showTypedNoteSheet) {
            AddTypedNoteSheet(voiceNotes: $voiceNotes)
        }
        .onAppear {
            Task {
                _ = await recorderManager.requestPermissions()
                _ = await speechManager.requestAuthorization()
            }
        }
    }
    
    private func toggleRecording() {
        if !recorderManager.isRecording {
            Task {
                _ = await recorderManager.requestPermissions()
                _ = await speechManager.requestAuthorization()
                recorderManager.startRecording()
                isPulseAnimating = true
            }
        } else if recorderManager.isPaused {
            recorderManager.resumeRecording()
        } else {
            recorderManager.pauseRecording()
        }
    }
    
    private func cancelRecording() {
        _ = recorderManager.stopRecording()
        isPulseAnimating = false
    }
    
    private func finishRecordingAndPromptSave() {
        isPulseAnimating = false
        noteTitle = "Ses Notu \(voiceNotes.count + 1)"
        customTranscript = ""
        isTranscribing = false
        
        // Kaydı durdur ve dosyayı tamamen kapat
        guard let (fileName, duration, levels) = recorderManager.stopRecording() else {
            return
        }
        
        savedFileName = fileName
        savedDuration = duration
        savedLevels = levels
        
        showSaveSheet = true
        isTranscribing = true
        
        Task {
            let fileURL = recorderManager.getAudioFileURL(fileName: fileName)
            
            // Dosyanın diskte finalize olması için kısa bekleme
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            print("🎙️ Kaydedilen ses dosyası analiz ediliyor: \(fileName)")
            
            // 1. Önce Apple Speech ile dene (Gerçek iPhone'da 100% çalışır)
            var finalResult = await speechManager.transcribeAudioFile(url: fileURL)
            
            // 2. Apple Speech başarısız olursa (Simülatördeki Error 1101 hatası) -> Gemini AI ile dene
            if finalResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("⚡ Apple Speech sonuç vermedi (Simülatör kısıtlaması/Error 1101). Gemini AI deneniyor...")
                if let geminiResult = await aiManager.processAudioFileWithGemini(fileURL: fileURL, category: selectedCategory) {
                    if !geminiResult.transcript.isEmpty {
                        finalResult = geminiResult.transcript
                        print("✅ Gemini AI transkripsiyonu başarılı: \"\(finalResult)\"")
                    }
                }
            }
            
            await MainActor.run {
                if !finalResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.customTranscript = finalResult
                    print("✅ Transkript Metin Kutununa Yazıldı: \"\(finalResult)\"")
                } else {
                    print("⚠️ Transkript alınamadı. ( Xcode Simülatöründe Apple Speech 'Error 1101' verir. Ayarlar'dan Gemini API Key girerek veya Gerçek Cihazda (iPhone) test edebilirsiniz.)")
                    self.customTranscript = ""
                }
                self.isTranscribing = false
            }
        }
    }
    
    private var saveNoteSheet: some View {
        ZStack {
            VoiceTheme.bgDark.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("Ses Notunu Kaydet")
                        .font(.title2.bold())
                        .foregroundColor(VoiceTheme.textPrimary)
                    Spacer()
                    Button(action: { showSaveSheet = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(VoiceTheme.textSecondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not Başlığı")
                        .font(.caption.bold())
                        .foregroundColor(VoiceTheme.textSecondary)
                    TextField("Başlık girin...", text: $noteTitle)
                        .padding()
                        .background(VoiceTheme.bgCard)
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VoiceTheme.bgCardBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Konuşma Metni (Düzenlenebilir)")
                        .font(.caption.bold())
                        .foregroundColor(VoiceTheme.textSecondary)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $customTranscript)
                            .frame(height: 85)
                            .padding(6)
                            .scrollContentBackground(.hidden)
                            .background(VoiceTheme.bgCard)
                            .cornerRadius(14)
                            .foregroundColor(.white)
                        
                        if customTranscript.isEmpty {
                            Text("✨ Konuşmanız kaydedildi. İsterseniz buraya notunuzu yazabilir veya 'Kaydet & AI Analizi Çıkar' butonuna basarak Gemini AI'ın sesinizi dinleyip metne dökmesini sağlayabilirsiniz...")
                                .font(.caption)
                                .foregroundColor(VoiceTheme.textSecondary.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VoiceTheme.bgCardBorder, lineWidth: 1)
                    )
                }
                
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedCategory == category ? VoiceTheme.primaryGlow : VoiceTheme.bgCard)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selectedCategory == category ? VoiceTheme.accentCyan : VoiceTheme.bgCardBorder, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
                
                if isTranscribing {
                    HStack(spacing: 12) {
                        ProgressView().tint(VoiceTheme.accentCyan)
                        Text("🎙️ Konuşmanız metne dönüştürülüyor...")
                            .font(.subheadline)
                            .foregroundColor(VoiceTheme.accentCyan)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(VoiceTheme.accentCyan.opacity(0.1))
                    .cornerRadius(14)
                } else if isProcessingAi {
                    HStack(spacing: 12) {
                        ProgressView().tint(VoiceTheme.accentCyan)
                        Text("✨ Yapay zeka analiz ediyor...")
                            .font(.subheadline)
                            .foregroundColor(VoiceTheme.accentCyan)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(VoiceTheme.accentCyan.opacity(0.1))
                    .cornerRadius(14)
                }
                
                Button(action: saveVoiceNote) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Kaydet & AI Analizi Çıkar")
                            .font(.headline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(VoiceTheme.recordButtonGradient)
                    .cornerRadius(18)
                    .shadow(color: VoiceTheme.primaryGlow.opacity(0.5), radius: 10, x: 0, y: 4)
                }
                .disabled(isProcessingAi)
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private func saveVoiceNote() {
        // Dosya zaten finishRecordingAndPromptSave içinde stopRecording() ile kapatıldı.
        // savedFileName/Duration/Levels state değişkenlerinden okuyoruz.
        let fileName = savedFileName
        let duration = savedDuration
        let levels = savedLevels
        
        guard !fileName.isEmpty else {
            showSaveSheet = false
            return
        }
        
        isProcessingAi = true
        Task {
            let fileURL = recorderManager.getAudioFileURL(fileName: fileName)
            
            var finalTranscript = customTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            var finalSummary = ""
            var finalActions: [String] = []
            
            // 1. Transkripsiyon henüz devam ediyorsa veya boşsa Apple Speech ile dene
            if finalTranscript.isEmpty {
                print("🔄 Kaydet sırasında Apple Speech çalıştırılıyor...")
                let appleResult = await speechManager.transcribeAudioFile(url: fileURL)
                if !appleResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalTranscript = appleResult
                    print("✅ Kaydet — Apple Speech: \(finalTranscript)")
                }
            }
            
            // 2. Hâlâ boşsa Gemini ile dene
            if finalTranscript.isEmpty {
                if let result = await aiManager.processAudioFileWithGemini(fileURL: fileURL, category: selectedCategory) {
                    if !result.transcript.isEmpty {
                        finalTranscript = result.transcript
                        finalSummary  = result.summary
                        finalActions  = result.actionItems
                    }
                }
            }
            
            // 3. Metin varsa AI analizi yaptır
            if !finalTranscript.isEmpty && finalSummary.isEmpty {
                let (summary, actions) = await aiManager.summarizeTranscription(finalTranscript, category: selectedCategory)
                finalSummary = summary
                finalActions = actions
            }
            
            // 4. Son seçenek: düzenlenebilir metin
            if finalTranscript.isEmpty {
                finalTranscript = "Ses kaydı alındı. Detay sayfasından metni düzenleyebilirsiniz."
                finalSummary    = "Ses kaydı başarıyla tamamlandı."
                finalActions    = ["• Ses kaydının ayrıntılarını gözden geçir.", "• Not kategorisini ve başlığını güncelle."]
            }
            
            let newNote = VoiceNote(
                title: noteTitle.isEmpty ? "Ses Notu" : noteTitle,
                category: selectedCategory,
                audioFileName: fileName,
                duration: duration,
                createdAt: Date(),
                transcript: finalTranscript,
                aiSummary: finalSummary,
                actionItems: finalActions,
                isFavorite: false,
                audioLevels: levels
            )
            
            await MainActor.run {
                self.voiceNotes.insert(newNote, at: 0)
                self.isProcessingAi = false
                self.showSaveSheet = false
                self.savedFileName = ""
            }
        }
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
