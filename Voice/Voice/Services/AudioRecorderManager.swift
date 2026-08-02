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

    // Canlı konuşma tanımaya (Speech framework) ses buffer'ı iletmek için callback.
    // Gerçek zamanlı ses thread'inden çağrılır, MainActor'a hop yapmaz.
    nonisolated(unsafe) private var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // AVAudioEngine: TEK giriş noktası — hem dosyaya yazar hem canlı buffer'ları speech engine'e iletir.
    // Not: AVAudioRecorder ile AVAudioEngine aynı anda mikrofonu dinleyemez (iOS aynı girişe iki istemciyi
    // güvenilir şekilde bağlamıyor); bu yüzden ikisi arasında seçim yapılır, birlikte çalıştırılmaz.
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?

    // AVAudioEngine başlatılamazsa (nadir donanım/format hatası) devreye giren yedek kayıt yolu
    private var audioRecorder: AVAudioRecorder?
    private var isUsingFallbackRecorder = false

    private var timer: Timer?

    public override init() {
        super.init()
    }

    /// Kayıt başlamadan önce çağrılır; her ses buffer'ı geldiğinde `handler` tetiklenir.
    public func setLiveBufferHandler(_ handler: ((AVAudioPCMBuffer) -> Void)?) {
        onAudioBuffer = handler
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
        let fileName = "VoiceNote_\(UUID().uuidString).wav"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        currentRecordingFileName = fileName
        isUsingFallbackRecorder = false

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

        // inputFormat.settings kullanarak AVAudioFile oluştur — format uyumsuzluğunu engeller
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)
        } catch {
            print("❌ AudioRecorderManager: AVAudioFile oluşturulamadı: \(error). Yedek kayıt kullanılıyor.")
            startFallbackRecorder(fileURL: fileURL, fileName: fileName)
            return
        }

        inputNode.removeTap(onBus: 0)
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
            print("AudioRecorderManager: AVAudioEngine başlatılamadı: \(error). Yedek kayıt kullanılıyor.")
            inputNode.removeTap(onBus: 0)
            audioFile = nil
            startFallbackRecorder(fileURL: fileURL, fileName: fileName)
        }
    }

    // MARK: - Yedek Kayıt (AVAudioRecorder — sadece AVAudioEngine başarısız olursa)
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
            print("✅ AudioRecorderManager [Yedek]: AVAudioRecorder başladı — \(fileName)")
        } catch {
            print("⚠️ AudioRecorderManager [Yedek]: AVAudioRecorder başlatılamadı: \(error)")
        }

        isRecording = true
        isPaused = false
        recordingTime = 0
        liveAudioLevels.removeAll()
        startTimer()
    }

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
            audioFile = nil // Dosyayı kapat (flush to disk)
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

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                self.recordingTime += 0.1

                if self.isUsingFallbackRecorder, let rec = self.audioRecorder, rec.isRecording {
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
