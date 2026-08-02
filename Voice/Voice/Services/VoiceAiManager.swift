import Foundation

@MainActor
@Observable
public final class VoiceAiManager {
    /// Gemini API Key'inizi Ayarlar sayfasından girebilirsiniz:
    public static let defaultApiKey: String = ""
    
    public var apiKey: String = ""
    public var isProcessing: Bool = false
    
    private let endpointTemplates = [
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=",
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key="
    ]
    
    public init(apiKey: String = "") {
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
            self.apiKey = savedKey.isEmpty ? Self.defaultApiKey : savedKey
        }
    }
    
    public func processAudioFileWithGemini(fileURL: URL, category: NoteCategory = .general) async -> (transcript: String, summary: String, actionItems: [String])? {
        guard let audioData = try? Data(contentsOf: fileURL), !audioData.isEmpty else {
            print("VoiceAiManager: Ses dosyası okunamadı veya boş.")
            return nil
        }
        
        let base64Audio = audioData.base64EncodedString()
        let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let activeKey = [apiKey, savedKey, Self.defaultApiKey]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
            
        guard !activeKey.isEmpty else {
            print("VoiceAiManager: Aktif Gemini API Key bulunamadı.")
            return nil
        }
        
        let promptText: String
        if category == .song {
            promptText = """
            Sen profesyonel bir Türk söz yazarı ve ses analistisisin.
            Ektekı ses kaydını dinle ve yanıtını şu 3 açık bölümde ver:
            
            DÖKÜM:
            [Ses kaydında konuşulan veya söylenen kelimelerin BİREBİR Türkçe metin dökümünü çıkar.]
            
            ÖZET:
            [Bu fikirden ilham alarak Şarkı İsmi, Müzik Tarzı (Pop/Akustik/Rock vb.), Giriş, Kıta 1, Nakarat, Kıta 2 ve Çıkış bölümlerinden oluşan ritmik Türkçe şarkı sözü beste üret.]
            
            AKSİYON:
            • 120 BPM Melodik Pop/Akustik Ritim Önerisi
            • Vokal ve Akustik Gitar Altyapısı
            """
        } else {
            promptText = """
            Sen profesyonel bir Türkçe ses asistanısın.
            Ektekı ses kaydını dinle ve yanıtını şu 3 açık bölümde ver:
            
            DÖKÜM:
            [Ses kaydında konuşulan Türkçe kelimelerin BİREBİR metin dökümünü çıkar.]
            
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
                            "inlineData": [
                                "mimeType": "audio/m4a",
                                "data": base64Audio
                            ]
                        ],
                        [
                            "text": promptText
                        ]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonPayload) else {
            return nil
        }
        
        for template in endpointTemplates {
            guard let url = URL(string: template + activeKey) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("Gemini Audio API Endpoint '\(template)' HTTP Durum Kodu: \(statusCode)")
                
                if statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let reply = parts.first?["text"] as? String {
                        
                        print("Gemini Audio AI İşleme Başarılı!\n\(reply)")
                        return parseGeminiAudioReply(reply)
                    }
                } else {
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("Gemini API Endpoint '\(template)' Yanıt (\(statusCode)): \(rawString)")
                    }
                }
            } catch {
                print("Gemini API Endpoint Hatası: \(error)")
            }
        }
        
        return nil
    }
    
    private func parseGeminiAudioReply(_ reply: String) -> (transcript: String, summary: String, actionItems: [String]) {
        var transcript = ""
        var summary = ""
        var actions: [String] = []
        
        var currentSection = ""
        let lines = reply.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("DÖKÜM:") || trimmed.uppercased().hasPrefix("METİN DÖKÜMÜ:") {
                currentSection = "dokum"
                let val = trimmed.replacingOccurrences(of: "DÖKÜM:", with: "").replacingOccurrences(of: "METİN DÖKÜMÜ:", with: "").trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { transcript += val + "\n" }
            } else if trimmed.uppercased().hasPrefix("ÖZET:") || trimmed.uppercased().hasPrefix("ŞARKI:") {
                currentSection = "ozet"
                let val = trimmed.replacingOccurrences(of: "ÖZET:", with: "").replacingOccurrences(of: "ŞARKI:", with: "").trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { summary += val + "\n" }
            } else if trimmed.uppercased().hasPrefix("AKSİYON:") || trimmed.uppercased().hasPrefix("RİTİM:") {
                currentSection = "aksiyon"
            } else {
                if currentSection == "dokum" && !trimmed.isEmpty {
                    transcript += line + "\n"
                } else if currentSection == "ozet" && !trimmed.isEmpty {
                    summary += line + "\n"
                } else if currentSection == "aksiyon" && !trimmed.isEmpty {
                    if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                        actions.append(trimmed)
                    } else {
                        actions.append("• " + trimmed)
                    }
                }
            }
        }
        
        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (
            finalTranscript.isEmpty ? reply : finalTranscript,
            finalSummary.isEmpty ? "Özet ses kaydından oluşturuldu." : finalSummary,
            actions.isEmpty ? ["• Ses kaydı detayları incelenecektir."] : actions
        )
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
        
        for template in endpointTemplates {
            guard let url = URL(string: template + cleanKey) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                if statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let reply = parts.first?["text"] as? String {
                        
                        print("Gemini API Endpoint '\(template)' Özeti/Şarkı Sözü Başarıyla Alındı!")
                        let lines = reply.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        
                        let actions = lines.filter { $0.contains("•") || $0.contains("-") || $0.contains("*") }
                        let summaryLines = lines.filter { !$0.contains("•") && !$0.contains("-") && !$0.contains("*") }
                        
                        let summary = summaryLines.joined(separator: "\n")
                        let finalActions = actions.isEmpty ? ["• 120 BPM Melodik Ritim", "• Akustik & Bas Altyapı"] : Array(actions)
                        
                        return (summary, finalActions)
                    }
                }
            } catch {
                print("Gemini API Ağ Hatası: \(error)")
            }
        }
        
        return generateLocalSmartSummary(text: text, category: category)
    }
}
