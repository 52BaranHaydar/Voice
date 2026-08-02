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
    public var isSimulatorMode: Bool = false
    
    // Canlı ses buffer'larını Speech Recognition'a iletmek için callback
    // Yalnızca gerçek cihazda ve AVAudioEngine kullanıldığında çağrılır
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    // Simülatör için: AVAudioRecorder (gerçek dosya yazar)
    private var audioRecorder: AVAudioRecorder?
    
    // Gerçek cihaz için: AVAudioEngine (hem dosya yazar hem buffer iletir)
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    
    private var timer: Timer?
    
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
        currentRecordingFileName = fileName
        
        #if targetEnvironment(simulator)
        startRecordingSimulator(fileURL: fileURL, fileName: fileName)
        #else
        startRecordingEngine(fileURL: fileURL, fileName: fileName)
        #endif
    }
    
    // MARK: - Simülatör Kayıt (AVAudioRecorder — gerçek .m4a dosyası oluşturur)
    
    private func startRecordingSimulator(fileURL: URL, fileName: String) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
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
            print("✅ AudioRecorderManager [Simülatör]: AVAudioRecorder başladı — \(fileName)")
        } catch {
            print("⚠️ AudioRecorderManager [Simülatör]: AVAudioRecorder başlatılamadı: \(error)")
            // Simülatörde gerçek ses yok, yine de boş dosya oluştur
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }
        
        isRecording = true
        isPaused = false
        recordingTime = 0
        liveAudioLevels.removeAll()
        startTimer()
    }
    
    // MARK: - Gerçek Cihaz Kayıt (AVAudioEngine — canlı buffer akışı destekler)
    
    private func startRecordingEngine(fileURL: URL, fileName: String) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try session.setActive(true)
        } catch {
            print("AudioRecorderManager: AVAudioSession hatası: \(error)")
            // AVAudioSession başarısız olursa AVAudioRecorder ile fallback
            startRecordingSimulator(fileURL: fileURL, fileName: fileName)
            return
        }
        #endif
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // m4a hedef dosyası
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            print("AudioRecorderManager: AVAudioFile oluşturulamadı: \(error). AVAudioRecorder'a düşüyoruz.")
            startRecordingSimulator(fileURL: fileURL, fileName: fileName)
            return
        }
        
        // Tek tap: dosyaya yaz + speech buffer'a ilet + seviye hesapla
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 1. Dosyaya yaz
            try? self.audioFile?.write(from: buffer)
            
            // 2. Speech recognition'a ilet
            self.onAudioBuffer?(buffer)
            
            // 3. Ses seviyesi ölçümü
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
            print("✅ AudioRecorderManager [Gerçek Cihaz]: AVAudioEngine başladı — \(fileName)")
        } catch {
            print("AudioRecorderManager: AVAudioEngine başlatılamadı: \(error)")
            inputNode.removeTap(onBus: 0)
            audioFile = nil
            startRecordingSimulator(fileURL: fileURL, fileName: fileName)
        }
    }
    
    // MARK: - Pause / Resume / Stop
    
    public func pauseRecording() {
        if isSimulatorMode {
            audioRecorder?.pause()
        } else {
            audioEngine.pause()
        }
        isPaused = true
        timer?.invalidate()
    }
    
    public func resumeRecording() {
        if isSimulatorMode {
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
        
        if isSimulatorMode {
            audioRecorder?.stop()
            audioRecorder = nil
        } else {
            if audioEngine.isRunning {
                audioEngine.inputNode.removeTap(onBus: 0)
                audioEngine.stop()
            }
            audioFile = nil  // Dosyayı kapat (flush)
        }
        
        onAudioBuffer = nil
        isRecording = false
        isPaused = false
        
        guard let fileName = currentRecordingFileName else { return nil }
        let duration = max(1.0, recordingTime)
        let levels = liveAudioLevels.isEmpty
            ? [0.3, 0.5, 0.7, 0.4, 0.6, 0.8, 0.5, 0.3]
            : liveAudioLevels
        
        print("✅ AudioRecorderManager: Kayıt durduruldu — \(fileName), süre: \(String(format: "%.1f", duration))s")
        return (fileName, duration, levels)
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.recordingTime += 0.1
                
                // Simülatörde seviye simulasyonu
                if self.isSimulatorMode {
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
