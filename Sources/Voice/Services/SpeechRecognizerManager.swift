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
        stopTranscribing()
        isTranscribing = true
        liveTranscript = ""
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech Recognizer yerel dili desteklemiyor.")
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
                    }
                }
            }
        }
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
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguageCode)) ?? SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            return ""
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }
                if let result = result, result.isFinal {
                    hasResumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if error != nil {
                    hasResumed = true
                    let fallbackStr = result?.bestTranscription.formattedString ?? ""
                    continuation.resume(returning: fallbackStr)
                }
            }
        }
    }
}
