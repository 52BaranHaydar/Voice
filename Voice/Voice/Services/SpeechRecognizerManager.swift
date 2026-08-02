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
    private var audioEngine = AVAudioEngine()
    
    public override init() {
        super.init()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
        self.speechRecognizer?.delegate = self
    }
    
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self.isAvailable = true
                        continuation.resume(returning: true)
                    default:
                        self.isAvailable = true
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    public func startLiveTranscribing() {
        // Canlı transkripsiyon devre dışı:
        // AudioRecorderManager zaten mikrofonu kullanıyor.
        // Transkripsiyon için kayıt bittikten sonra
        // transcribeAudioFile(url:) çağrılmalıdır.
        isTranscribing = false
        liveTranscript = ""
    }
    
    private func startRealAudioEngineStream(with recognizer: SFSpeechRecognizer) {
        stopAudioEngine()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine başlatılamadı: \(error)")
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let result = result, !result.bestTranscription.formattedString.isEmpty {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if error != nil {
                    print("Speech recognition task error: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
    
    public func stopTranscribing() {
        stopAudioEngine()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
    }
    
    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    public func setLanguage(_ code: String) {
        selectedLanguageCode = code
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: code))
    }
    
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
        
        // 2. Dosya var mı kontrol et
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ SpeechRecognizer: Dosya bulunamadı: \(url.path)")
            return ""
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        print("🎙️ SpeechRecognizer: Dosya boyutu = \(fileSize) bytes, URL = \(url.lastPathComponent)")
        
        guard fileSize > 1000 else {
            print("❌ SpeechRecognizer: Dosya çok küçük, ses kaydı boş olabilir.")
            return ""
        }
        
        // 3. AVAudioSession'ı kayıt modundan çıkar — bu olmadan SFSpeech çalışmaz!
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ AVAudioSession: playback moduna geçildi")
        } catch {
            print("⚠️ AVAudioSession ayarlanamadı: \(error.localizedDescription)")
        }
        #endif
        
        // 4. Sırayla Türkçe → İngilizce dene
        let localesToTry = [selectedLanguageCode, "tr-TR", "en-US"]
        
        for locale in localesToTry {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
                print("⚠️ SpeechRecognizer [\(locale)]: Tanıyıcı oluşturulamadı")
                continue
            }
            
            if !recognizer.isAvailable {
                print("⚠️ SpeechRecognizer [\(locale)]: isAvailable = false")
                continue
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false
            
            print("🔄 SpeechRecognizer [\(locale)]: Transkripsiyon başlıyor...")
            
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
        
        print("❌ SpeechRecognizer: Tüm dil denemeleri başarısız.")
        return ""
    }
}
