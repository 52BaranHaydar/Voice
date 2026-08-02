import Foundation
import Speech
import AVFoundation

/// SpeechRecognizerManager
/// MainActor - UI state yönetimi için
/// Önemli: liveRequest nonisolated(unsafe) olarak saklanır,
/// böylece AVAudioEngine tap'inin gerçek zamanlı audio thread'inden kilitlenme (deadlock) olmadan erişilir.
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
        let localesToTry = [locale, "tr-TR", "en-US", Locale.current.identifier]
        for loc in localesToTry {
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: loc)), recognizer.isAvailable {
                speechRecognizer = recognizer
                speechRecognizer?.delegate = self
                speechRecognizer?.defaultTaskHint = .dictation
                print("✅ SpeechManager: SFSpeechRecognizer hazır (\(loc))")
                return
            }
        }
        
        // Son çare: varsayılan recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) ?? SFSpeechRecognizer()
        speechRecognizer?.delegate = self
        speechRecognizer?.defaultTaskHint = .dictation
    }
    
    // MARK: - Authorization
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.isAvailable = (status == .authorized)
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    // MARK: - Live Transcription (Buffer-Based)
    /// AVAudioEngine tap'inden gelen buffer'ları anlık kabul eder.
    public func startLiveTranscribingWithBuffers() -> SFSpeechAudioBufferRecognitionRequest? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("⚠️ SpeechManager: Konuşma tanıma izni yok.")
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
                        print("🎙️ Canlı Metin: \"\(text)\"")
                    }
                }
                
                if let error = error {
                    let code = (error as NSError).code
                    // 209, 216, 300, 301, 1110 normal bitiş/iptal kodlarıdır
                    let normalCodes: Set<Int> = [209, 216, 300, 301, 1110]
                    if !normalCodes.contains(code) {
                        print("⚠️ SpeechManager canlı hata [\(code)]: \(error.localizedDescription)")
                    }
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
    
    // Eski API uyumluluğu
    public func startLiveTranscribing() {}
    public func stopTranscribing() { stopLiveTranscribing() }
    
    public func setLanguage(_ code: String) {
        selectedLanguageCode = code
        setupRecognizer(locale: code)
    }
    
    // MARK: - File Transcription (Kayıt bittikten sonra yedek yöntem)
    public func transcribeAudioFile(url: URL) async -> String {
        let authGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .authorized {
                cont.resume(returning: true)
            } else {
                SFSpeechRecognizer.requestAuthorization { s in
                    cont.resume(returning: s == .authorized)
                }
            }
        }
        guard authGranted else { return "" }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ SpeechRecognizer: Dosya yok: \(url.lastPathComponent)")
            return ""
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size > 500 else {
            print("❌ SpeechRecognizer: Dosya çok küçük (\(size) bytes)")
            return ""
        }
        
        #if os(iOS)
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default)
            try s.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ AVAudioSession: \(error.localizedDescription)")
        }
        #endif
        
        for locale in [selectedLanguageCode, "tr-TR", "en-US"] {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
                  recognizer.isAvailable else { continue }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false
            
            print("🔄 SpeechRecognizer [\(locale)]: Dosyadan transkripsiyon...")
            
            let text: String = await withCheckedContinuation { cont in
                var done = false
                var best = ""
                recognizer.recognitionTask(with: request) { result, error in
                    guard !done else { return }
                    if let r = result { best = r.bestTranscription.formattedString; if r.isFinal { done = true; cont.resume(returning: best) } }
                    if let e = error { done = true; print("❌ [\(locale)] \(e.localizedDescription)"); cont.resume(returning: best) }
                }
            }
            
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("✅ SpeechRecognizer [\(locale)]: \"\(text)\"")
                return text
            }
        }
        return ""
    }
    
    // MARK: - Delegate
    public nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in self.isAvailable = available }
    }
}
