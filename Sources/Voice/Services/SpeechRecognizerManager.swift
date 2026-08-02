import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
public final class SpeechRecognizerManager: NSObject, SFSpeechRecognizerDelegate {
    public var liveTranscript: String = ""
    public var isTranscribing: Bool = false
    public var isAvailable: Bool = false
    public var selectedLanguageCode: String = "tr-TR"
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    public override init() {
        super.init()
        setupRecognizer()
    }
    
    private func setupRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
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
    // AudioRecorderManager'ın onAudioBuffer callback'ine bağlanır.
    // Mikrofonu kendisi açmaz — kayıt motorundan buffer alır.
    
    public func startLiveTranscribingWithBuffers() -> SFSpeechAudioBufferRecognitionRequest? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("⚠️ SpeechManager: Yetkilendirme yok, canlı transkripsiyon başlatılamıyor.")
            return nil
        }
        
        setupRecognizer()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("⚠️ SpeechManager: Tanıyıcı mevcut değil.")
            return nil
        }
        
        stopLiveTranscribing()
        
        liveTranscript = ""
        isTranscribing = true
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        self.liveTranscript = text
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    // 209 = kLSRErrorDomain recognition cancelled (normal)
                    // 301 = no speech detected (normal)
                    if nsError.code != 209 && nsError.code != 301 {
                        print("⚠️ SpeechManager canlı hata [\(nsError.code)]: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        print("✅ SpeechManager: Canlı transkripsiyon buffer modu başladı (\(selectedLanguageCode))")
        return request
    }
    
    public func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    public func stopLiveTranscribing() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
    }
    
    // Eski API uyumluluğu için
    public func startLiveTranscribing() {
        // Artık kullanılmıyor — startLiveTranscribingWithBuffers() kullanın
    }
    
    public func stopTranscribing() {
        stopLiveTranscribing()
    }
    
    public func setLanguage(_ code: String) {
        selectedLanguageCode = code
        setupRecognizer()
    }
    
    // MARK: - File Transcription (Kayıt bittikten sonra)
    
    public func transcribeAudioFile(url: URL) async -> String {
        // 1. Yetkilendirme kontrolü
        let authGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let current = SFSpeechRecognizer.authorizationStatus()
            if current == .authorized {
                cont.resume(returning: true)
            } else {
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        }
        
        guard authGranted else {
            print("❌ SpeechRecognizer: Yetkilendirme reddedildi.")
            return ""
        }
        
        // 2. Dosya var mı?
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ SpeechRecognizer: Dosya bulunamadı: \(url.path)")
            return ""
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        print("🎙️ SpeechRecognizer: Dosya: \(url.lastPathComponent), boyut: \(fileSize) bytes")
        
        guard fileSize > 500 else {
            print("❌ SpeechRecognizer: Dosya çok küçük.")
            return ""
        }
        
        // 3. AVAudioSession'ı playback moduna al
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ AVAudioSession ayarlanamadı: \(error.localizedDescription)")
        }
        #endif
        
        // 4. Türkçe → İngilizce sırasıyla dene
        let localesToTry = [selectedLanguageCode, "tr-TR", "en-US"]
        
        for locale in localesToTry {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
                  recognizer.isAvailable else {
                print("⚠️ SpeechRecognizer [\(locale)]: Mevcut değil")
                continue
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false
            
            print("🔄 SpeechRecognizer [\(locale)]: Başlıyor...")
            
            let result: String = await withCheckedContinuation { continuation in
                var hasResumed = false
                var bestSoFar = ""
                
                recognizer.recognitionTask(with: request) { taskResult, error in
                    guard !hasResumed else { return }
                    
                    if let r = taskResult {
                        bestSoFar = r.bestTranscription.formattedString
                        if r.isFinal {
                            hasResumed = true
                            print("✅ SpeechRecognizer [\(locale)]: \"\(bestSoFar)\"")
                            continuation.resume(returning: bestSoFar)
                        }
                    }
                    
                    if let err = error {
                        let nsErr = err as NSError
                        print("❌ SpeechRecognizer [\(locale)] hata \(nsErr.code): \(err.localizedDescription)")
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: bestSoFar)
                        }
                    }
                }
            }
            
            if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return result
            }
        }
        
        print("❌ SpeechRecognizer: Tüm denemeler başarısız.")
        return ""
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    public nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.isAvailable = available
        }
    }
}
