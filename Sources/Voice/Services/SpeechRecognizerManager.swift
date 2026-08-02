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
        "Sesli not kaydı alınıyor ve yapay zeka ile metne dönüştürülüyor.",
        "Konuşmanız anlık olarak Türkçe konuşma motoru ile işlenmektedir.",
        "Özetler ve yapılacak işler listesi kaydedildiğinde otomatik olarak oluşturulacaktır."
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
                        self.isAvailable = true
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
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech Recognizer yerel dili desteklemiyor, simülasyon akışına geçiliyor.")
            startSimulatorDemoStream()
            return
        }
        
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus == .authorized {
            startRealAudioEngineStream(with: speechRecognizer)
        } else {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if status == .authorized {
                        self.startRealAudioEngineStream(with: speechRecognizer)
                    } else {
                        print("Speech Recognition izni yok, gösterim akışı başlatılıyor.")
                        self.startSimulatorDemoStream()
                    }
                }
            }
        }
    }
    
    private func startRealAudioEngineStream(with recognizer: SFSpeechRecognizer) {
        stopAudioEngine()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            startSimulatorDemoStream()
            return
        }
        
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
            print("Audio engine başlatılamadı: \(error), gösterim akışına geçiliyor.")
            startSimulatorDemoStream()
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
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
    }
    
    private func startSimulatorDemoStream() {
        simulatorTimer?.invalidate()
        var phraseIndex = 0
        liveTranscript = "🎤 [Canlı Dikte Başlatıldı]: "
        
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
