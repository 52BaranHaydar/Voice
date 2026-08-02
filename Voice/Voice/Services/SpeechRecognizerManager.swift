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
        // Önce yetkilendirme isteği
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
            print("SpeechRecognizer: Yetkilendirme reddedildi.")
            return ""
        }
        
        // Seçili dili dene; başarısız olursa en-US ile dene
        let localesToTry: [String] = [selectedLanguageCode, "tr-TR", "en-US"]
        
        for locale in localesToTry {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
                  recognizer.isAvailable else { continue }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.addsPunctuation = true
            
            print("SpeechRecognizer: \(locale) ile transkripsiyon başlıyor...")
            
            let result: String = await withCheckedContinuation { continuation in
                var hasResumed = false
                var bestSoFar = ""
                
                recognizer.recognitionTask(with: request) { taskResult, error in
                    guard !hasResumed else { return }
                    
                    if let r = taskResult {
                        bestSoFar = r.bestTranscription.formattedString
                        if r.isFinal {
                            hasResumed = true
                            print("✅ SpeechRecognizer [\(locale)]: \(bestSoFar)")
                            continuation.resume(returning: bestSoFar)
                        }
                    }
                    
                    if let err = error {
                        print("SpeechRecognizer [\(locale)] hata: \(err.localizedDescription)")
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
        
        return ""
    }
}
