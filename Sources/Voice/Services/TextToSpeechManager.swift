import Foundation
import AVFoundation

@MainActor
@Observable
public final class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    public var isSpeaking: Bool = false
    public var selectedLanguageCode: String = "tr-TR"
    
    private let synthesizer = AVSpeechSynthesizer()
    
    public override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    public func speak(text: String, languageCode: String = "tr-TR") {
        stopSpeaking()
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
