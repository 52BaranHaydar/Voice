import Foundation
import AVFoundation

@MainActor
@Observable
public final class AudioRecorderManager: NSObject {
    public var isRecording: Bool = false
    public var isPaused: Bool = false
    public var recordingTime: TimeInterval = 0
    public var liveAudioLevels: [Float] = []
    public var currentRecordingFileName: String?
    public var isSimulatorMode: Bool = false
    
    // Dış tarafın ses buffer'larına abone olması için callback
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var currentFileURL: URL?
    
    public override init() {
        super.init()
        #if targetEnvironment(simulator)
        self.isSimulatorMode = true
        #endif
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
        currentFileURL = fileURL
        currentRecordingFileName = fileName
        
        #if targetEnvironment(simulator)
        // Simülatörde gerçek mikrofon yok — sadece timer ile simüle et
        isRecording = true
        isPaused = false
        recordingTime = 0
        liveAudioLevels.removeAll()
        startTimer(simulatorMode: true)
        return
        #endif
        
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
        } catch {
            print("AudioRecorderManager: AVAudioSession hatası: \(error)")
        }
        #endif
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Dışa aktarım formatı: mono, 44100Hz, AAC için uygun PCM
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) ?? inputFormat
        
        // Hedef: m4a / AAC dosyası
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            print("AudioRecorderManager: Dosya oluşturulamadı: \(error)")
            return
        }
        
        // Mikrofon tap: hem dosyaya yaz hem speech callback'e ilet
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Dosyaya yaz
            try? self.audioFile?.write(from: buffer)
            
            // Ses seviyesi ölçümü
            if let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                var rms: Float = 0
                for i in 0..<frameCount {
                    rms += channelData[i] * channelData[i]
                }
                rms = sqrt(rms / Float(frameCount))
                let normalized = max(0.05, min(1.0, rms * 10.0))
                Task { @MainActor [weak self] in
                    guard let self = self, self.isRecording, !self.isPaused else { return }
                    self.liveAudioLevels.append(normalized)
                    if self.liveAudioLevels.count > 50 { self.liveAudioLevels.removeFirst() }
                }
            }
            
            // Speech recognition callback'e ilet
            self.onAudioBuffer?(buffer)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            isPaused = false
            recordingTime = 0
            liveAudioLevels.removeAll()
            startTimer(simulatorMode: false)
            print("✅ AudioRecorderManager: Kayıt başladı — \(fileName)")
        } catch {
            print("AudioRecorderManager: Engine başlatılamadı: \(error)")
            inputNode.removeTap(onBus: 0)
        }
    }
    
    public func pauseRecording() {
        audioEngine.pause()
        isPaused = true
        timer?.invalidate()
    }
    
    public func resumeRecording() {
        do {
            try audioEngine.start()
            isPaused = false
            startTimer(simulatorMode: isSimulatorMode)
        } catch {
            print("AudioRecorderManager: Resume hatası: \(error)")
        }
    }
    
    public func stopRecording() -> (fileName: String, duration: TimeInterval, levels: [Float])? {
        timer?.invalidate()
        timer = nil
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        // Dosyayı kapat
        audioFile = nil
        onAudioBuffer = nil
        
        isRecording = false
        isPaused = false
        
        guard let fileName = currentRecordingFileName else { return nil }
        let duration = max(1.0, recordingTime)
        let levels = liveAudioLevels.isEmpty ? [0.3, 0.5, 0.7, 0.4, 0.6, 0.8, 0.5, 0.3] : liveAudioLevels
        
        print("✅ AudioRecorderManager: Kayıt durduruldu — \(fileName), süre: \(String(format: "%.1f", duration))s")
        return (fileName, duration, levels)
    }
    
    private func startTimer(simulatorMode: Bool) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.recordingTime += 0.1
                
                if simulatorMode {
                    let level = Float.random(in: 0.2...0.85)
                    self.liveAudioLevels.append(level)
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
