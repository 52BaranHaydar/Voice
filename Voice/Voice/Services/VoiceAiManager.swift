import Foundation

@MainActor
@Observable
public final class VoiceAiManager {
    /// Gemini API Key'inizi Ayarlar sayfasından girebilirsiniz:
    public static let defaultApiKey: String = ""
    
    public var apiKey: String = ""
    public var isProcessing: Bool = false
    
    // v1 / v1beta API ile desteklenen, stabil model adları (en güncel önce)
    private let audioModels = [
        "gemini-1.5-flash",
        "gemini-2.0-flash",
        "gemini-1.5-pro"
    ]
    
    public init(apiKey: String = "") {
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
            self.apiKey = savedKey.isEmpty ? Self.defaultApiKey : savedKey
        }
    }
    
    private var activeKey: String {
        let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        return [apiKey, savedKey, Self.defaultApiKey]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
    
    public func processAudioFileWithGemini(fileURL: URL, category: NoteCategory = .general) async -> (transcript: String, summary: String, actionItems: [String])? {
        guard let audioData = try? Data(contentsOf: fileURL), !audioData.isEmpty else {
            print("VoiceAiManager: Ses dosyası okunamadı veya boş.")
            return nil
        }
        
        let key = activeKey
        guard !key.isEmpty else {
            print("VoiceAiManager: Aktif Gemini API Key bulunamadı.")
            return nil
        }
        
        let base64Audio = audioData.base64EncodedString()
        let mimeType: String
        switch fileURL.pathExtension.lowercased() {
        case "wav": mimeType = "audio/wav"
        case "m4a", "mp4": mimeType = "audio/mp4"
        case "caf": mimeType = "audio/x-caf"
        case "aiff", "aif": mimeType = "audio/aiff"
        default: mimeType = "audio/mp4"
        }
        
        let promptText: String
        if category == .song {
            promptText = """
            Sen profesyonel bir Türk söz yazarı ve ses analistisisin.
            Bu ses kaydını dinle ve yanıtını şu 3 bölümde ver:
            
            DÖKÜM:
            [Ses kaydındaki konuşmanın BİREBİR Türkçe metin dökümünü çıkar.]
            
            ÖZET:
            [Bu fikirden ilham alarak Şarkı İsmi, Müzik Tarzı, Giriş, Kıta 1, Nakarat, Kıta 2 ve Çıkış bölümlerinden oluşan ritmik Türkçe şarkı sözü üret.]
            
            AKSİYON:
            • 120 BPM Melodik Pop/Akustik Ritim Önerisi
            • Vokal ve Akustik Gitar Altyapısı
            """
        } else {
            promptText = """
            Sen profesyonel bir Türkçe ses asistanısın.
            Bu ses kaydını dinle ve yanıtını şu 3 bölümde ver:
            
            DÖKÜM:
            [Ses kaydındaki konuşmanın BİREBİR Türkçe metin dökümünü çıkar.]
            
            ÖZET:
            [Ses kaydındaki ana konuyu açıklayan net ve öz bir Türkçe özet yaz.]
            
            AKSİYON:
            • Konuşmadan çıkarılan yapılacak iş 1
            • Konuşmadan çıkarılan yapılacak iş 2
            """
        }
        
        let jsonPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Audio
                            ]
                        ],
                        ["text": promptText]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonPayload) else {
            return nil
        }
        
        // v1 endpoint ile dene (v1beta'ya göre daha geniş model desteği)
        for model in audioModels {
            for apiVersion in ["v1", "v1beta"] {
                let urlStr = "https://generativelanguage.googleapis.com/\(apiVersion)/models/\(model):generateContent?key=\(key)"
                guard let url = URL(string: urlStr) else { continue }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 60
                request.httpBody = httpBody
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("Gemini Audio [\(apiVersion)/\(model)] HTTP: \(statusCode)")
                    
                    if statusCode == 200 {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let candidates = json["candidates"] as? [[String: Any]],
                           let firstCandidate = candidates.first,
                           let content = firstCandidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let reply = parts.first?["text"] as? String {
                            print("✅ Gemini Audio İşleme Başarılı [\(apiVersion)/\(model)]")
                            return parseGeminiAudioReply(reply)
                        }
                    } else if statusCode == 404 {
                        continue // Bu model yok, sonraki modeli dene
                    } else if statusCode == 429 {
                        print("⚠️ Gemini [\(model)] kota doldu (429), sonraki model deneniyor...")
                        continue // Farklı kotalara sahip sonraki modelleri dene (gemini-1.5-flash vb.)
                    } else {
                        if let rawString = String(data: data, encoding: .utf8) {
                            print("Gemini Audio [\(apiVersion)/\(model)] Yanıt (\(statusCode)): \(rawString)")
                        }
                    }
                } catch {
                    print("Gemini Audio [\(apiVersion)/\(model)] Hata: \(error)")
                }
            }
        }
        
        print("VoiceAiManager: Tüm Gemini multimodal ses modelleri erişilemez.")
        return nil
    }
    
    private func parseGeminiAudioReply(_ reply: String) -> (transcript: String, summary: String, actionItems: [String]) {
        var transcript = ""
        var summary = ""
        var actions: [String] = []
        var currentSection = ""
        
        for line in reply.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("DÖKÜM:") {
                currentSection = "dokum"
                let val = trimmed.dropFirst("DÖKÜM:".count).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { transcript += val + "\n" }
            } else if trimmed.uppercased().hasPrefix("ÖZET:") || trimmed.uppercased().hasPrefix("ŞARKI:") {
                currentSection = "ozet"
                let val = trimmed.dropFirst("ÖZET:".count).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { summary += val + "\n" }
            } else if trimmed.uppercased().hasPrefix("AKSİYON:") {
                currentSection = "aksiyon"
            } else if !trimmed.isEmpty {
                switch currentSection {
                case "dokum": transcript += line + "\n"
                case "ozet": summary += line + "\n"
                case "aksiyon":
                    let bullet = (trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*")) ? trimmed : "• \(trimmed)"
                    actions.append(bullet)
                default: break
                }
            }
        }
        
        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (
            finalTranscript.isEmpty ? reply : finalTranscript,
            finalSummary.isEmpty ? "Ses kaydından özet çıkarıldı." : finalSummary,
            actions.isEmpty ? ["• Ses kaydı detayları incelenecektir."] : actions
        )
    }
    
    public func summarizeTranscription(_ text: String, category: NoteCategory = .general) async -> (summary: String, actionItems: [String]) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ("Ses kaydı için henüz metin dökümü bulunmuyor.", [])
        }
        
        let key = activeKey
        if !key.isEmpty {
            return await generateGeminiSummary(text: text, category: category, key: key)
        }
        return generateLocalSmartSummary(text: text, category: category)
    }
    
    private func generateLocalSmartSummary(text: String, category: NoteCategory) -> (summary: String, actionItems: [String]) {
        if category == .song {
            let firstLine = text.components(separatedBy: .newlines).first ?? text
            return (
                "🎵 AI Şarkı Beste Önerisi: '\(firstLine.prefix(25))...'\n\n[Giriş]\nRitim yükselir yavaşça...\n\n[Kıta 1]\n\(text)\n\n[Nakarat]\nSesim dalgalanır ritimle beraber,\nYazılan her not bir beste eder.",
                ["• Ritim Önerisi: 120 BPM Pop/Akustik Tempo", "• Vokal Tarzı: Melodik ve Hissiyatlı Dikte"]
            )
        }
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let summaryText = sentences.count <= 2 ? "Özet: \(text)" : "Özet: \(sentences.prefix(2).joined(separator: ". "))."
        
        let actionKeywords = ["yapılacak", "hazırlanacak", "edilecek", "tamamla", "görüş", "toplantı", "planla", "gönder", "yaz", "incele"]
        var actions = sentences.filter { sentence in
            let lower = sentence.lowercased()
            return actionKeywords.contains(where: { lower.contains($0) })
        }.map { "• \($0)" }
        
        if actions.isEmpty {
            actions = ["• Ses kaydının ayrıntılarını gözden geçir.", "• Not kategorisini ve başlığını güncelle."]
        }
        
        return (summaryText, actions)
    }
    
    private func generateGeminiSummary(text: String, category: NoteCategory, key: String) async -> (summary: String, actionItems: [String]) {
        let prompt = category == .song ? """
            Sen profesyonel bir Türk söz yazarı ve müzik bestecisisin.
            Aşağıdaki fikirden harika bir Türkçe şarkı beste ve sözü oluştur.
            [Giriş], [Kıta 1], [Nakarat], [Kıta 2] ve [Çıkış] bölümleriyle yaz.
            Madde işaretleriyle (•) ritim/enstrüman tavsiyeleri ekle.
            Konu: "\(text)"
            """ : """
            Aşağıdaki ses notu dökümünü Türkçe olarak analiz et:
            1. Net ve öz bir özet çıkar.
            2. Madde işaretleriyle (•) yapılacak işleri sırala.
            Metin: "\(text)"
            """
        
        let jsonPayload: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonPayload) else {
            return generateLocalSmartSummary(text: text, category: category)
        }
        
        for model in ["gemini-2.0-flash", "gemini-1.5-flash-latest", "gemini-1.5-flash"] {
            for apiVersion in ["v1", "v1beta"] {
                let urlStr = "https://generativelanguage.googleapis.com/\(apiVersion)/models/\(model):generateContent?key=\(key)"
                guard let url = URL(string: urlStr) else { continue }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = httpBody
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    
                    if statusCode == 200,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let content = candidates.first?["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let reply = parts.first?["text"] as? String {
                        
                        let lines = reply.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        let actions = lines.filter { $0.hasPrefix("•") || $0.hasPrefix("-") || $0.hasPrefix("*") }
                        let summaryLines = lines.filter { !$0.hasPrefix("•") && !$0.hasPrefix("-") && !$0.hasPrefix("*") }
                        return (summaryLines.joined(separator: "\n"), actions.isEmpty ? ["• Detayları inceleyin."] : actions)
                    } else if statusCode != 404 {
                        break
                    }
                } catch { continue }
            }
        }
        
        return generateLocalSmartSummary(text: text, category: category)
    }
}
