import Foundation
import SwiftUI

@MainActor
@Observable
public final class VoiceNoteStore {
    public var notes: [VoiceNote] = []
    
    private let fileName = "voice_notes.json"
    
    public init() {
        loadNotes()
    }
    
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
    
    public func loadNotes() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Seed initial sample notes if first launch
            self.notes = Self.defaultSampleNotes
            saveNotes()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            self.notes = try decoder.decode([VoiceNote].self, from: data)
            print("✅ VoiceNoteStore: \(notes.count) adet not yüklendi.")
        } catch {
            print("❌ VoiceNoteStore yükleme hatası: \(error). Varsayılan veriler yükleniyor.")
            self.notes = Self.defaultSampleNotes
        }
    }
    
    public func saveNotes() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            print("✅ VoiceNoteStore: Notlar başarıyla kaydedildi (\(notes.count) adet).")
        } catch {
            print("❌ VoiceNoteStore kaydetme hatası: \(error)")
        }
    }
    
    public func addNote(_ note: VoiceNote) {
        notes.insert(note, at: 0)
        saveNotes()
    }
    
    public func updateNote(_ note: VoiceNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            saveNotes()
        }
    }
    
    public func toggleFavorite(_ note: VoiceNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isFavorite.toggle()
            saveNotes()
        }
    }
    
    public func deleteNote(_ note: VoiceNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            let noteToDelete = notes[index]
            deleteAudioFile(fileName: noteToDelete.audioFileName)
            notes.remove(at: index)
            saveNotes()
        }
    }
    
    public func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            if index < notes.count {
                deleteAudioFile(fileName: notes[index].audioFileName)
            }
        }
        notes.remove(atOffsets: offsets)
        saveNotes()
    }
    
    private func deleteAudioFile(fileName: String) {
        guard !fileName.isEmpty else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Ses dosyası silindi: \(fileName)")
        }
    }
    
    public static var defaultSampleNotes: [VoiceNote] {
        [
            VoiceNote(
                title: "Proje Beyin Fırtınası",
                category: .idea,
                audioFileName: "",
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
                audioFileName: "",
                duration: 120,
                createdAt: Date().addingTimeInterval(-86400),
                transcript: "Gelecek hafta yayınlanacak sürüm öncesi performans testleri yapılacak. Firebase entegrasyonu tamamlandı.",
                aiSummary: "Özet: Ekip toplantısında performans testleri ve yeni sürüm hazırlıkları görüşüldü.",
                actionItems: ["• Performans testlerini yürüt", "• App Store yayın belgelerini hazırla"],
                isFavorite: false,
                audioLevels: [0.1, 0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.5, 0.3, 0.2]
            )
        ]
    }
}
