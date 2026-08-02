import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
public final class SpeechRecognizerManager: NSObject, SFSpeechRecognizerDelegate {
    
    // MARK: - Published State
    public var liveTranscript: String = ""
    public var isTranscribing: Bool = false
    public var isAvailable: Bool = false
    public var selectedLanguageCode: String = "tr-TR"
    
    // MARK: - Private State
    private var speechRecognizer: SFSpeechRecognizer?
    
    // MARK: - Init
    public override init() {
        super.init()
        setupRecognizer(locale: selectedLanguageCode)
    }
    
    private func setupRecognizer(locale: String) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
            ?? SFSpeechRecognizer()
        speechRecognizer?.delegate = self
        speechRecognizer?.defaultTaskHint = .dictation
        print("✅ SpeechManager: SFSpeechRecognizer hazır (\(speechRecognizer?.locale.identifier ?? locale))")
    }
    
    // MARK: - Authorization
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.isAvailable = (status == .authorized)
                    print("🎙️ SpeechManager Yetki Durumu: \(status.rawValue) (Authorized = \(status == .authorized))")
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    public func setLanguage(_ code: String) {
        selectedLanguageCode = code
        setupRecognizer(locale: code)
    }
    
    // MARK: - File Transcription (Kayıt bitince .m4a dosyasından metin çıkarma)
    public func transcribeAudioFile(url: URL) async -> String {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            print("⚠️ transcribeAudioFile: İzin yetersiz (\(status.rawValue))")
            return ""
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ transcribeAudioFile: Dosya bulunamadı: \(url.path)")
            return ""
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size > 500 else {
            print("⚠️ transcribeAudioFile: Dosya çok küçük (\(size) bytes)")
            return ""
        }
        
        #if os(iOS)
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try s.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ AVAudioSession: \(error.localizedDescription)")
        }
        #endif
        
        let targetLocale = selectedLanguageCode.isEmpty ? "tr-TR" : selectedLanguageCode
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: targetLocale)) else {
            print("❌ transcribeAudioFile: [\(targetLocale)] tanıyıcı oluşturulamadı.")
            return ""
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false
        
        print("🔄 transcribeAudioFile [\(targetLocale)]: Dosya analiz ediliyor: \(url.lastPathComponent)")
        
        let text: String = await withCheckedContinuation { cont in
            var done = false
            var best = ""
            recognizer.recognitionTask(with: request) { result, error in
                guard !done else { return }
                if let r = result {
                    best = r.bestTranscription.formattedString
                    if r.isFinal {
                        done = true
                        cont.resume(returning: best)
                    }
                }
                if let e = error {
                    done = true
                    print("⚠️ transcribeAudioFile [\(targetLocale)] hatası: \(e.localizedDescription)")
                    cont.resume(returning: best)
                }
            }
        }
        
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("✅ SpeechRecognizer [\(targetLocale) dosya]: \"\(text)\"")
            return text
        }
        
        print("❌ transcribeAudioFile: [\(targetLocale)] dilinde sonuç alınamadı.")
        return ""
    }
    
    // MARK: - Delegate
    public nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in self.isAvailable = available }
    }
}
