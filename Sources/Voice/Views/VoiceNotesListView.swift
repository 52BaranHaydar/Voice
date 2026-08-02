import SwiftUI

public struct VoiceNotesListView: View {
    @Binding public var voiceNotes: [VoiceNote]
    @State private var searchText: String = ""
    @State private var selectedCategoryFilter: NoteCategory? = nil
    @State private var showOnlyFavorites: Bool = false
    
    @State private var playerManager = AudioPlayerManager()
    @State private var ttsManager = TextToSpeechManager()
    @State private var selectedNoteForDetail: VoiceNote? = nil
    @State private var showAddTypedNoteSheet: Bool = false
    
    public init(voiceNotes: Binding<[VoiceNote]>) {
        self._voiceNotes = voiceNotes
    }
    
    public var filteredNotes: [VoiceNote] {
        voiceNotes.filter { note in
            let matchesSearch = searchText.isEmpty || note.title.localizedCaseInsensitiveContains(searchText) || note.transcript.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategoryFilter == nil || note.category == selectedCategoryFilter
            let matchesFavorite = !showOnlyFavorites || note.isFavorite
            return matchesSearch && matchesCategory && matchesFavorite
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                VoiceTheme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Header Action Row
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not Kütüphanesi")
                                .font(.title2.bold())
                                .foregroundColor(VoiceTheme.textPrimary)
                            Text("Sesli ve yazılı notlarınız")
                                .font(.caption)
                                .foregroundColor(VoiceTheme.textSecondary)
                        }
                        Spacer()
                        
                        Button(action: { showAddTypedNoteSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                Text("+ Yazılı Not")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(VoiceTheme.primaryGlow)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: VoiceTheme.primaryGlow.opacity(0.4), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(VoiceTheme.textSecondary)
                        TextField("Sesli veya yazılı notlarda ara...", text: $searchText)
                            .foregroundColor(.white)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(VoiceTheme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(VoiceTheme.bgCard)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Category Chips Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Button(action: { selectedCategoryFilter = nil }) {
                                Text("Tümü (\(voiceNotes.count))")
                                    .font(.subheadline)
                                    .fontWeight(selectedCategoryFilter == nil ? .bold : .medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategoryFilter == nil ? VoiceTheme.primaryGlow : VoiceTheme.bgCard)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                            
                            ForEach(NoteCategory.allCases) { cat in
                                Button(action: { selectedCategoryFilter = cat }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.iconName)
                                        Text(cat.rawValue)
                                    }
                                    .font(.subheadline)
                                    .fontWeight(selectedCategoryFilter == cat ? .bold : .medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategoryFilter == cat ? VoiceTheme.primaryGlow : VoiceTheme.bgCard)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Stats & Favorites Toggle
                    HStack {
                        Text("\(filteredNotes.count) Not")
                            .font(.caption)
                            .foregroundColor(VoiceTheme.textSecondary)
                        Spacer()
                        Button(action: { showOnlyFavorites.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: showOnlyFavorites ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                Text("Favoriler")
                                    .font(.caption)
                                    .foregroundColor(VoiceTheme.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes List
                    if filteredNotes.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "note.text")
                                .font(.system(size: 48))
                                .foregroundColor(VoiceTheme.textSecondary)
                            Text("Henüz not bulunmuyor")
                                .font(.headline)
                                .foregroundColor(VoiceTheme.textSecondary)
                            Button(action: { showAddTypedNoteSheet = true }) {
                                Text("İlk Yazılı Notunu Ekle")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(VoiceTheme.accentCyan)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredNotes) { note in
                                    noteCard(for: note)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Notlarım")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showAddTypedNoteSheet) {
                AddTypedNoteSheet(voiceNotes: $voiceNotes)
            }
            .sheet(item: $selectedNoteForDetail) { note in
                VoiceNoteDetailView(note: binding(for: note), playerManager: playerManager, ttsManager: ttsManager)
            }
        }
    }
    
    private func noteCard(for note: VoiceNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: note.category.iconName)
                    Text(note.category.rawValue)
                }
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VoiceTheme.primaryGlow.opacity(0.3))
                .foregroundColor(VoiceTheme.accentCyan)
                .cornerRadius(8)
                
                if note.audioFileName.isEmpty {
                    Text("YAZILI NOT")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VoiceTheme.accentPink.opacity(0.3))
                        .foregroundColor(VoiceTheme.accentPink)
                        .cornerRadius(6)
                }
                
                Spacer()
                
                Text(note.formattedDuration)
                    .font(.caption.monospaced())
                    .foregroundColor(VoiceTheme.accentCyan)
                
                Button(action: { toggleFavorite(note) }) {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .foregroundColor(note.isFavorite ? .yellow : VoiceTheme.textSecondary)
                }
            }
            
            Text(note.title)
                .font(.headline)
                .foregroundColor(VoiceTheme.textPrimary)
            
            if !note.transcript.isEmpty {
                Text(note.transcript)
                    .font(.subheadline)
                    .foregroundColor(VoiceTheme.textSecondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                if !note.audioFileName.isEmpty {
                    Button(action: {
                        if playerManager.currentlyPlayingFileName == note.audioFileName && playerManager.isPlaying {
                            playerManager.pauseAudio()
                        } else {
                            playerManager.playAudio(fileName: note.audioFileName)
                        }
                    }) {
                        Image(systemName: (playerManager.currentlyPlayingFileName == note.audioFileName && playerManager.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(VoiceTheme.accentCyan)
                    }
                } else {
                    Button(action: {
                        if ttsManager.isSpeaking {
                            ttsManager.stopSpeaking()
                        } else {
                            ttsManager.speak(text: note.transcript)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            Text(ttsManager.isSpeaking ? "Durdur" : "Sesli Oku")
                                .font(.caption.bold())
                        }
                        .foregroundColor(VoiceTheme.accentPink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VoiceTheme.accentPink.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
                
                AudioWaveformView(levels: note.audioLevels, isRecording: false)
                    .frame(height: 35)
                
                Spacer()
                
                Button(action: { selectedNoteForDetail = note }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(VoiceTheme.textSecondary)
                }
            }
        }
        .glassCardStyle()
        .onTapGesture {
            selectedNoteForDetail = note
        }
    }
    
    private func toggleFavorite(_ note: VoiceNote) {
        if let index = voiceNotes.firstIndex(where: { $0.id == note.id }) {
            voiceNotes[index].isFavorite.toggle()
        }
    }
    
    private func binding(for note: VoiceNote) -> Binding<VoiceNote> {
        guard let index = voiceNotes.firstIndex(where: { $0.id == note.id }) else {
            fatalError("Note not found")
        }
        return $voiceNotes[index]
    }
}
