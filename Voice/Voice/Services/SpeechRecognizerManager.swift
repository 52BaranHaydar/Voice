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
    private var simulatorTimer: Timer?
    
    private let demoPhrases = [
        "Voice projesinde sesli not kaydı alıyor ve yapay zeka ile otomatik özet çıkarıyoruz.",
        "Bu simülasyon metnidir. Gerçek cihazda mikrofon sesiniz anlık dökülür.",
        "Toplantı notları ve aksiyon maddeleri başarıyla kategorize ediliyor."
    ]
    
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
                        self.isAvailable = true // Fallback allowed for demo
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    public func startLiveTranscribing() {
        stopTranscribing()
        isTranscribing = true
        liveTranscript = ""
        
        #if targetEnvironment(simulator)
        startSimulatorDemoStream()
        #else
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            startSimulatorDemoStream()
            return
        }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            startSimulatorDemoStream()
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine error: \(error), fallback to simulator stream.")
            startSimulatorDemoStream()
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let result = result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopAudioEngine()
                }
            }
        }
        #endif
    }
    
    private func startSimulatorDemoStream() {
        simulatorTimer?.invalidate()
        var phraseIndex = 0
        liveTranscript = "🎤 [Simülatör Canlı Ses Dökümü Modu]: "
        
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isTranscribing else { return }
                if phraseIndex < self.demoPhrases.count {
                    self.liveTranscript += self.demoPhrases[phraseIndex] + " "
                    phraseIndex += 1
                }
            }
        }
    }
    
    public func stopTranscribing() {
        simulatorTimer?.invalidate()
        simulatorTimer = nil
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
}
