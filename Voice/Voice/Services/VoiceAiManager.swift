import Foundation

@MainActor
@Observable
public final class VoiceAiManager {
    /// Gemini API Key'inizi Ayarlar sayfasından girebilirsiniz:
    public static let defaultApiKey: String = ""
    
    public var apiKey: String = ""
    public var isProcessing: Bool = false
    
    public init(apiKey: String = "") {
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
            self.apiKey = savedKey.isEmpty ? Self.defaultApiKey : savedKey
        }
    }
    
    public func summarizeTranscription(_ text: String, category: NoteCategory = .general) async -> (summary: String, actionItems: [String]) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ("Ses kaydı için henüz metin dökümü bulunmuyor.", [])
        }
        
        let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let activeKey = [apiKey, savedKey, Self.defaultApiKey]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
        
        if !activeKey.isEmpty {
            return await generateGeminiSummary(text: text, category: category, key: activeKey)
        } else {
            print("VoiceAiManager: API Key bulunamadı, yerel akıllı özetleme kullanılıyor.")
            return generateLocalSmartSummary(text: text, category: category)
        }
    }
    
    private func generateLocalSmartSummary(text: String, category: NoteCategory) -> (summary: String, actionItems: [String]) {
        if category == .song {
            let firstLine = text.components(separatedBy: .newlines).first ?? text
            return (
                "🎵 AI Şarkı Beste Önerisi: '\(firstLine.prefix(25))...'\n\n[Giriş]\nRitim yükselir yavaşça...\n\n[Kıta 1]\n\(text)\n\n[Nakarat]\nSesim dalgalanır ritimle beraber,\nYazılan her not bir beste eder.",
                [
                    "• Ritim Önerisi: 120 BPM Pop/Akustik Tempo",
                    "• Vokal Tarzı: Melodik ve Hissiyatlı Dikte",
                    "• Enstrümanlar: Akustik Gitar & Bas"
                ]
            )
        }
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let summaryText: String
        if sentences.count <= 2 {
            summaryText = "Özet: " + text
        } else {
            let firstTwo = sentences.prefix(2).joined(separator: ". ")
            summaryText = "Özet: " + firstTwo + "."
        }
        
        let actionKeywords = ["yapılacak", "hazırlanacak", "edilecek", "tamamla", "görüş", "toplantı", "planla", "gönder", "yaz", "incele", "projeyi"]
        var actions: [String] = []
        
        for sentence in sentences {
            let lower = sentence.lowercased()
            if actionKeywords.contains(where: { lower.contains($0) }) {
                actions.append("• " + sentence)
            }
        }
        
        if actions.isEmpty {
            actions = [
                "• Ses kaydının ayrıntılarını gözden geçir.",
                "• Not kategorisini ve başlığını güncelle."
            ]
        }
        
        return (summaryText, actions)
    }
    
    private func generateGeminiSummary(text: String, category: NoteCategory, key: String) async -> (summary: String, actionItems: [String]) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(cleanKey)") else {
            print("Gemini API Error: Geçersiz URL veya API Key")
            return generateLocalSmartSummary(text: text, category: category)
        }
        
        let prompt: String
        if category == .song {
            prompt = """
            Sen profesyonel bir Türk söz yazarı ve müzik bestecisisin.
            Aşağıdaki konuşma veya fikirden ilham alarak harika bir Türkçe şarkı beste ve sözü oluştur.
            
            Format:
            1. Yanıtın ilk 2 satırında yaratıcı bir Şarkı İsmi ve Müzik Tarzı (Pop, Akustik, Rock vb.) belirt.
            2. Sonrasında [Giriş], [Kıta 1], [Nakarat], [Kıta 2] ve [Çıkış] bölümlerinden oluşan ritmik şarkı sözlerini yaz.
            3. En son kısımda madde işaretleri (•) kullanarak ritim/BPM ve enstrüman tavsiyelerini sırala.
            
            Konu/Fikir:
            "\(text)"
            """
        } else {
            prompt = """
            Aşağıdaki ses notu metin dökümünü analiz et. Türkçe olarak:
            1. İlk satırda net ve öz bir özet çıkar.
            2. Sonraki satırlarda madde işaretleri (•) kullanarak yapılacak işleri liste şeklinde sırala.
            
            Metin:
            "\(text)"
            """
        }
        
        let jsonPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonPayload) else {
            return generateLocalSmartSummary(text: text, category: category)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Gemini API HTTP Durum Kodu: \(httpResponse.statusCode)")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let reply = parts.first?["text"] as? String {
                
                print("Gemini AI Özeti/Şarkı Sözü Başarıyla Alındı!")
                let lines = reply.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                
                let actions = lines.filter { $0.contains("•") || $0.contains("-") || $0.contains("*") }
                let summaryLines = lines.filter { !$0.contains("•") && !$0.contains("-") && !$0.contains("*") }
                
                let summary = summaryLines.joined(separator: "\n")
                let finalActions = actions.isEmpty ? ["• 120 BPM Melodik Ritim", "• Akustik & Bas Altyapı"] : Array(actions)
                
                return (summary, finalActions)
            } else {
                if let rawString = String(data: data, encoding: .utf8) {
                    print("Gemini API Ham Yanıt: \(rawString)")
                }
            }
        } catch {
            print("Gemini API Ağ Hatası: \(error)")
        }
        
        return generateLocalSmartSummary(text: text, category: category)
    }
}
