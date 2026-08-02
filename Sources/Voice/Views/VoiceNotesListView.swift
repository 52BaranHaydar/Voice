import SwiftUI

public struct VoiceNotesListView: View {
    @Binding public var voiceNotes: [VoiceNote]
    @State private var searchText: String = ""
    @State private var selectedCategoryFilter: NoteCategory? = nil
    @State private var showOnlyFavorites: Bool = false
    
    @State private var playerManager = AudioPlayerManager()
    @State private var selectedNoteForDetail: VoiceNote? = nil
    
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
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(VoiceTheme.textSecondary)
                        TextField("Ses notlarında ara...", text: $searchText)
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
                    
                    // Favorite Toggle & Stats Row
                    HStack {
                        Text("\(filteredNotes.count) Ses Notu")
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
                            Image(systemName: "mic.slash")
                                .font(.system(size: 48))
                                .foregroundColor(VoiceTheme.textSecondary)
                            Text("Henüz ses notu bulunmuyor")
                                .font(.headline)
                                .foregroundColor(VoiceTheme.textSecondary)
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedNoteForDetail) { note in
                VoiceNoteDetailView(note: binding(for: note), playerManager: playerManager)
            }
        }
    }
    
    private func noteCard(for note: VoiceNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Category Tag
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
            
            // Audio Playback Bar
            HStack(spacing: 12) {
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
