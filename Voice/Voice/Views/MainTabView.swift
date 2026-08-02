import SwiftUI

public struct MainTabView: View {
    @State private var voiceNotes: [VoiceNote] = [
        VoiceNote(
            title: "Proje Beyin Fırtınası",
            category: .idea,
            audioFileName: "sample1.m4a",
            duration: 45,
            createdAt: Date().addingTimeInterval(-3600),
            transcript: "Voice projesinde ses kaydı alıp anında yapay zeka ile özet çıkaran harika bir iOS uygulaması geliştiriyoruz.",
            aiSummary: "Özet: Voice uygulaması geliştirilmesi üzerine fikir alışverişi yapıldı.",
            actionItems: ["• Ses dalga boyu animasyonunu tamamla", "• Speech Framework entegrasyonunu kontrol et"],
            isFavorite: true,
            audioLevels: [0.2, 0.4, 0.7, 0.9, 0.6, 0.3, 0.5, 0.8, 0.4, 0.2, 0.6, 0.8, 0.3]
        ),
        VoiceNote(
            title: "Haftalık Ekip Toplantısı",
            category: .meeting,
            audioFileName: "sample2.m4a",
            duration: 120,
            createdAt: Date().addingTimeInterval(-86400),
            transcript: "Gelecek hafta yayınlanacak sürüm öncesi performans testleri yapılacak. Firebase entegrasyonu tamamlandı.",
            aiSummary: "Özet: Ekip toplantısında performans testleri ve yeni sürüm hazırlıkları görüşüldü.",
            actionItems: ["• Performans testlerini yürüt", "• App Store yayın belgelerini hazırla"],
            isFavorite: false,
            audioLevels: [0.1, 0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.5, 0.3, 0.2]
        )
    ]
    
    public init() {}
    
    public var body: some View {
        TabView {
            RecorderView(voiceNotes: $voiceNotes)
                .tabItem {
                    Label("Stüdyo", systemImage: "mic.circle.fill")
                }
            
            VoiceNotesListView(voiceNotes: $voiceNotes)
                .tabItem {
                    Label("Notlarım", systemImage: "list.bullet.rectangle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Ayarlar", systemImage: "gearshape.fill")
                }
        }
        .tint(VoiceTheme.accentCyan)
    }
}
