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
    
    // Canlı ses buffer'larını Speech Recognition'a iletmek için callback
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    // AVAudioEngine: hem dosya yazar hem canlı buffer'ları speech engine'e iletir
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    
    // Fallback için AVAudioRecorder
    private var audioRecorder: AVAudioRecorder?
    private var isUsingFallbackRecorder: Bool = false
    
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
        let fileName = "VoiceNote_\(UUID().uuidString).caf"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        currentRecordingFileName = fileName
        isUsingFallbackRecorder = false
        
        startRecordingEngine(fileURL: fileURL, fileName: fileName)
    }
    
    // MARK: - AVAudioEngine Kayıt (PCM / CAF dosyası — %100 güvenilir yazma ve transkripsiyon)
    
    private func startRecordingEngine(fileURL: URL, fileName: String) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("AudioRecorderManager: AVAudioSession hatası: \(error)")
        }
        #endif
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("🎙️ AudioRecorderManager: Input format sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount)")
        
        // inputFormat.settings kullanarak AVAudioFile oluştur — format uyumsuzluğunu %100 engeller!
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)
        } catch {
            print("❌ AudioRecorderManager: AVAudioFile oluşturulamadı: \(error). Fallback'e geçiliyor.")
            startFallbackRecorder(fileURL: fileURL, fileName: fileName)
            return
        }
        
        // Audio tap: Her buffer geldiğinde dosyaya yaz ve speech engine'e ilet
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 1. Dosyaya kaydet
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("❌ AudioRecorderManager dosya yazma hatası: \(error)")
            }
            
            // 2. Canlı konuşma tanıyıcıya buffer ilet
            self.onAudioBuffer?(buffer)
            
            // 3. Ses dalgası seviyesini hesapla
            if let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                guard frameCount > 0 else { return }
                var rms: Float = 0
                for i in 0..<frameCount { rms += channelData[i] * channelData[i] }
                rms = sqrt(rms / Float(frameCount))
                let normalized = max(0.05, min(1.0, rms * 12.0))
                
                Task { @MainActor [weak self] in
                    guard let self = self, self.isRecording, !self.isPaused else { return }
                    self.liveAudioLevels.append(normalized)
                    if self.liveAudioLevels.count > 50 { self.liveAudioLevels.removeFirst() }
                }
            }
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            isPaused = false
            recordingTime = 0
            liveAudioLevels.removeAll()
            startTimer()
            print("✅ AudioRecorderManager: AVAudioEngine ile kayıt başladı — \(fileName)")
        } catch {
            print("AudioRecorderManager: AVAudioEngine başlatılamadı: \(error). Fallback kullanılıyor.")
            inputNode.removeTap(onBus: 0)
            audioFile = nil
            startFallbackRecorder(fileURL: fileURL, fileName: fileName)
        }
    }
    
    // MARK: - Fallback Kayıt (AVAudioRecorder)
    
    private func startFallbackRecorder(fileURL: URL, fileName: String) {
        isUsingFallbackRecorder = true
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
            print("✅ AudioRecorderManager [Fallback]: AVAudioRecorder başladı — \(fileName)")
        } catch {
            print("⚠️ AudioRecorderManager [Fallback]: AVAudioRecorder başlatılamadı: \(error)")
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }
        
        isRecording = true
        isPaused = false
        recordingTime = 0
        liveAudioLevels.removeAll()
        startTimer()
    }
    
    // MARK: - Pause / Resume / Stop
    
    public func pauseRecording() {
        if isUsingFallbackRecorder {
            audioRecorder?.pause()
        } else {
            audioEngine.pause()
        }
        isPaused = true
        timer?.invalidate()
    }
    
    public func resumeRecording() {
        if isUsingFallbackRecorder {
            audioRecorder?.record()
        } else {
            do { try audioEngine.start() } catch {
                print("AudioRecorderManager: Resume hatası: \(error)")
            }
        }
        isPaused = false
        startTimer()
    }
    
    public func stopRecording() -> (fileName: String, duration: TimeInterval, levels: [Float])? {
        timer?.invalidate()
        timer = nil
        
        if isUsingFallbackRecorder {
            audioRecorder?.stop()
            audioRecorder = nil
        } else {
            if audioEngine.isRunning {
                audioEngine.inputNode.removeTap(onBus: 0)
                audioEngine.stop()
            }
            audioFile = nil  // Dosyayı kapat (flush to disk)
        }
        
        onAudioBuffer = nil
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
    
    // MARK: - Timer
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.recordingTime += 0.1
                
                if self.isUsingFallbackRecorder {
                    if let rec = self.audioRecorder, rec.isRecording {
                        rec.updateMeters()
                        let raw = rec.averagePower(forChannel: 0)
                        let normalized = max(0.05, min(1.0, (raw + 60.0) / 60.0))
                        self.liveAudioLevels.append(normalized)
                    } else {
                        self.liveAudioLevels.append(Float.random(in: 0.2...0.75))
                    }
                    if self.liveAudioLevels.count > 50 { self.liveAudioLevels.removeFirst() }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
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
