import Foundation
import Speech
import AVFoundation

/// SpeechRecognizerManager
/// MainActor - UI state yönetimi için
/// Önemli: liveRequest nonisolated(unsafe) olarak saklanır,
/// böylece AVAudioEngine tap'inin gerçek zamanlı audio thread'inden kilitlenme olmadan erişilir.
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
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // thread-safe audio request handle
    nonisolated(unsafe) private var liveRequest: SFSpeechAudioBufferRecognitionRequest?
    
    // MARK: - Init
    public override init() {
        super.init()
        setupRecognizer(locale: selectedLanguageCode)
    }
    
    private func setupRecognizer(locale: String) {
        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) {
            speechRecognizer = recognizer
        } else if let fallback = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) {
            speechRecognizer = fallback
        } else {
            speechRecognizer = SFSpeechRecognizer()
        }
        speechRecognizer?.delegate = self
        speechRecognizer?.defaultTaskHint = .dictation
        print("✅ SpeechManager: SFSpeechRecognizer hazır (\(speechRecognizer?.locale.identifier ?? "unknown"))")
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
    
    // MARK: - Live Transcription (Buffer-Based)
    public func startLiveTranscribingWithBuffers() -> SFSpeechAudioBufferRecognitionRequest? {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            print("⚠️ SpeechManager: Konuşma tanıma izni yetersiz (Status: \(status.rawValue))")
            return nil
        }
        
        setupRecognizer(locale: selectedLanguageCode)
        
        guard let recognizer = speechRecognizer else {
            print("⚠️ SpeechManager: SFSpeechRecognizer oluşturulamadı.")
            return nil
        }
        
        stopLiveTranscribing()
        
        liveTranscript = ""
        isTranscribing = true
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.addsPunctuation = true
        self.liveRequest = request
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        self.liveTranscript = text
                        print("🎙️ CANLI YAZI GELDİ: \"\(text)\"")
                    }
                }
                
                if let error = error {
                    let code = (error as NSError).code
                    print("ℹ️ SpeechManager canlı task bildirimi [\(code)]: \(error.localizedDescription)")
                }
            }
        }
        
        print("✅ SpeechManager: Canlı transkripsiyon başlatıldı (\(recognizer.locale.identifier))")
        return request
    }
    
    /// Audio tap thread'inden güvenle çağrılır (nonisolated, thread-safe)
    public nonisolated func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        liveRequest?.append(buffer)
    }
    
    public func stopLiveTranscribing() {
        liveRequest?.endAudio()
        liveRequest = nil
        recognitionTask?.finish()
        recognitionTask = nil
        isTranscribing = false
    }
    
    public func startLiveTranscribing() {}
    public func stopTranscribing() { stopLiveTranscribing() }
    
    public func setLanguage(_ code: String) {
        selectedLanguageCode = code
        setupRecognizer(locale: code)
    }
    
    // MARK: - File Transcription (Periyodik veya kayıt sonu)
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
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try s.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ AVAudioSession: \(error.localizedDescription)")
        }
        #endif
        
        for locale in [selectedLanguageCode, "tr-TR", "en-US", Locale.current.identifier] {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else { continue }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false
            
            print("🔄 transcribeAudioFile [\(locale)]: Başlatılıyor...")
            
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
                        print("⚠️ transcribeAudioFile [\(locale)] hatası: \(e.localizedDescription)")
                        cont.resume(returning: best)
                    }
                }
            }
            
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("✅ SpeechRecognizer [\(locale) dosya]: \"\(text)\"")
                return text
            }
        }
        
        print("❌ transcribeAudioFile: Tüm dillerde sonuç boş döndü.")
        return ""
    }
    
    // MARK: - Delegate
    public nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in self.isAvailable = available }
    }
}
