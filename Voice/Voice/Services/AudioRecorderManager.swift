import Foundation
import AVFoundation

@MainActor
@Observable
public final class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
    public var isRecording: Bool = false
    public var isPaused: Bool = false
    public var recordingTime: TimeInterval = 0
    public var liveAudioLevels: [Float] = []
    public var currentRecordingFileName: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    public override init() {
        super.init()
    }
    
    public func requestPermissions() async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        return true
        #endif
    }
    
    public func startRecording() {
        let fileName = "VoiceNote_\(UUID().uuidString).m4a"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        currentRecordingFileName = fileName
        
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("AudioRecorderManager: AVAudioSession hatası: \(error)")
        }
        #endif
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            isPaused = false
            recordingTime = 0
            liveAudioLevels.removeAll()
            startTimer()
            print("✅ AudioRecorderManager: Kayıt başladı — \(fileName)")
        } catch {
            print("❌ AudioRecorderManager: Kayıt başlatılamadı: \(error)")
        }
    }
    
    public func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        timer?.invalidate()
    }
    
    public func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTimer()
    }
    
    public func stopRecording() -> (fileName: String, duration: TimeInterval, levels: [Float])? {
        timer?.invalidate()
        timer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        isRecording = false
        isPaused = false
        
        guard let fileName = currentRecordingFileName else { return nil }
        let duration = max(1.0, recordingTime)
        let levels = liveAudioLevels.isEmpty
            ? [0.3, 0.5, 0.7, 0.4, 0.6, 0.8, 0.5, 0.3]
            : liveAudioLevels
        
        print("✅ AudioRecorderManager: Kayıt tamamlandı — \(fileName), süre: \(String(format: "%.1f", duration))s")
        return (fileName, duration, levels)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.recordingTime += 0.1
                
                if let rec = self.audioRecorder, rec.isRecording {
                    rec.updateMeters()
                    let raw = rec.averagePower(forChannel: 0)
                    let normalized = max(0.05, min(1.0, (raw + 60.0) / 60.0))
                    self.liveAudioLevels.append(normalized)
                    if self.liveAudioLevels.count > 50 { self.liveAudioLevels.removeFirst() }
                }
            }
        }
    }
    
    public func getAudioFileURL(fileName: String) -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
