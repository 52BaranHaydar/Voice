import SwiftUI

public struct MainTabView: View {
    @State private var store = VoiceNoteStore()
    
    public init() {}
    
    public var body: some View {
        TabView {
            RecorderView(voiceNotes: $store.notes)
                .tabItem {
                    Label("Stüdyo", systemImage: "mic.circle.fill")
                }
                .onChange(of: store.notes) { _, _ in
                    store.saveNotes()
                }
            
            VoiceNotesListView(
                voiceNotes: $store.notes,
                onDeleteNote: { note in
                    store.deleteNote(note)
                }
            )
            .tabItem {
                Label("Notlarım", systemImage: "list.bullet.rectangle.fill")
            }
            .onChange(of: store.notes) { _, _ in
                store.saveNotes()
            }
            
            SettingsView()
                .tabItem {
                    Label("Ayarlar", systemImage: "gearshape.fill")
                }
        }
        .tint(VoiceTheme.accentCyan)
    }
}
