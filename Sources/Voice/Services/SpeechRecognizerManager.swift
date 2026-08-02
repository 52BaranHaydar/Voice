import Foundation
import Speech
import AVFoundation

@Observable
public final class SpeechRecognizerManager {
    public var liveTranscript: String = ""
    public var isTranscribing: Bool = false
    public var isAvailable: Bool = false
    public var selectedLanguageCode: String = "tr-TR"
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    public init(languageCode: String = "tr-TR") {
        self.selectedLanguageCode = languageCode
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
    }
    
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self.isAvailable = true
                        continuation.resume(returning: true)
                    default:
                        self.isAvailable = false
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    public func startLiveTranscribing() {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return }
        
        stopTranscribing()
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isTranscribing = true
            liveTranscript = ""
        } catch {
            print("Audio engine error: \(error)")
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopAudioEngine()
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
}
