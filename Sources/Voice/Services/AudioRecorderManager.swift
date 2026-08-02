import Foundation
import AVFoundation

#if canImport(Combine)
import Combine
#endif

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
        return await AVAudioSession.sharedInstance().requestRecordPermission()
        #else
        return true
        #endif
    }
    
    public func startRecording() {
        let fileName = "VoiceNote_\(UUID().uuidString).m4a"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
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
            currentRecordingFileName = fileName
            
            startTimer()
        } catch {
            print("Failed to start recording: \(error)")
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
        isRecording = false
        isPaused = false
        
        guard let fileName = currentRecordingFileName else { return nil }
        let duration = recordingTime
        let levels = liveAudioLevels
        
        return (fileName, duration, levels)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording, !self.isPaused else { return }
            self.recordingTime += 0.1
            
            self.audioRecorder?.updateMeters()
            let rawPower = self.audioRecorder?.averagePower(forChannel: 0) ?? -60
            // Normalize decibels [-60..0] dB to [0.05..1.0] level range
            let normalized = max(0.05, min(1.0, (rawPower + 60.0) / 60.0))
            self.liveAudioLevels.append(normalized)
            if self.liveAudioLevels.count > 50 {
                self.liveAudioLevels.removeFirst()
            }
        }
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
