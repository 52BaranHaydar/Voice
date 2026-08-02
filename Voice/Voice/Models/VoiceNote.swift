import Foundation

public enum NoteCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case general = "Genel"
    case meeting = "Toplantı"
    case idea = "Fikir"
    case song = "Şarkı / Beste"
    case personal = "Kişisel"
    case lecture = "Ders"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "note.text"
        case .meeting: return "person.2.fill"
        case .idea: return "lightbulb.fill"
        case .song: return "music.note.list"
        case .personal: return "heart.fill"
        case .lecture: return "book.fill"
        }
    }
}

public struct VoiceNote: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var category: NoteCategory
    public var audioFileName: String
    public var duration: TimeInterval
    public var createdAt: Date
    public var transcript: String
    public var aiSummary: String
    public var actionItems: [String]
    public var isFavorite: Bool
    public var audioLevels: [Float]
    
    public init(
        id: UUID = UUID(),
        title: String,
        category: NoteCategory = .general,
        audioFileName: String,
        duration: TimeInterval,
        createdAt: Date = Date(),
        transcript: String = "",
        aiSummary: String = "",
        actionItems: [String] = [],
        isFavorite: Bool = false,
        audioLevels: [Float] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.audioFileName = audioFileName
        self.duration = duration
        self.createdAt = createdAt
        self.transcript = transcript
        self.aiSummary = aiSummary
        self.actionItems = actionItems
        self.isFavorite = isFavorite
        self.audioLevels = audioLevels
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
