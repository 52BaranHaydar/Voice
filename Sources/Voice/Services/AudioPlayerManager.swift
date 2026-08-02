import Foundation
import AVFoundation

@Observable
public final class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    public var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var playbackRate: Float = 1.0
    public var currentlyPlayingFileName: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    public override init() {
        super.init()
    }
    
    public func playAudio(fileName: String) {
        if currentlyPlayingFileName == fileName && audioPlayer != nil {
            resumeAudio()
            return
        }
        
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist at path: \(fileURL.path)")
            return
        }
        
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            duration = audioPlayer?.duration ?? 0
            currentlyPlayingFileName = fileName
            
            startTimer()
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }
    
    public func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    public func resumeAudio() {
        audioPlayer?.rate = playbackRate
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    public func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        currentlyPlayingFileName = nil
        timer?.invalidate()
        timer = nil
    }
    
    public func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    public func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            audioPlayer?.rate = rate
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer, self.isPlaying else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, max(0.0, currentTime / duration))
    }
}
