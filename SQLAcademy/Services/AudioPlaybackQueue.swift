import AVFoundation
import Combine

/// Sequential audio buffer queue backed by AVAudioEngine.
///
/// Key design decisions vs the old SpeechManager:
/// 1. Audio format & engine connection set up ONCE — never disconnected/reconnected.
/// 2. AVAudioSession activated once per playback session, deactivated only after full queue drain.
/// 3. Buffers are queued and played sequentially via completion callbacks.
/// 4. All public API is @MainActor for safe SwiftUI observation.
@MainActor
final class AudioPlaybackQueue: ObservableObject {

    @Published private(set) var isPlaying = false

    private let sampleRate: Double
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let audioFormat: AVAudioFormat

    private var bufferQueue: [AVAudioPCMBuffer] = []
    private var isProcessingQueue = false
    private var sessionActive = false

    init(sampleRate: Double = 24000) {
        self.sampleRate = sampleRate
        // Create format once — reused for every buffer
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        setupEngine()
    }

    // MARK: - Public API

    /// Enqueue raw PCM Int16 data for playback. Starts playing immediately if idle.
    func enqueue(_ pcmData: Data) {
        guard let buffer = createBuffer(from: pcmData) else {
            log("Failed to create buffer from \(pcmData.count) bytes")
            return
        }
        log("Enqueued \(buffer.frameLength) frames (\(String(format: "%.1f", Double(buffer.frameLength) / sampleRate))s) — queue depth: \(bufferQueue.count + 1)")
        bufferQueue.append(buffer)
        playNextIfIdle()
    }

    /// Stop current playback and clear the queue.
    func stopAndClear() {
        let wasPlaying = isPlaying
        bufferQueue.removeAll()
        playerNode.stop()
        isPlaying = false
        isProcessingQueue = false
        if wasPlaying {
            log("Stopped and cleared queue")
            deactivateSession()
        }
    }

    /// Total duration of given PCM data.
    func duration(of pcmData: Data) -> TimeInterval {
        let frames = pcmData.count / 2
        guard frames > 0 else { return 0 }
        return TimeInterval(frames) / sampleRate
    }

    // MARK: - Engine Setup (once)

    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
        do {
            try engine.start()
            log("Engine started with format: \(audioFormat)")
        } catch {
            log("Engine start error: \(error)")
        }
    }

    // MARK: - Sequential Playback

    private func playNextIfIdle() {
        guard !isProcessingQueue else { return }
        guard !bufferQueue.isEmpty else {
            isPlaying = false
            deactivateSession()
            log("Queue drained — idle")
            return
        }

        isProcessingQueue = true
        let buffer = bufferQueue.removeFirst()

        activateSession()
        ensureEngineRunning()

        isPlaying = true
        log("Playing \(buffer.frameLength) frames (\(String(format: "%.1f", Double(buffer.frameLength) / sampleRate))s) — \(bufferQueue.count) remaining")

        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            // Hop back to MainActor for state updates
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isProcessingQueue = false
                self.log("Buffer complete")
                self.playNextIfIdle()
            }
        }

        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    // MARK: - Buffer Creation

    private func createBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let frameCount = data.count / 2
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        data.withUnsafeBytes { raw in
            guard let src = raw.baseAddress?.assumingMemoryBound(to: Int16.self),
                  let dst = buffer.floatChannelData?[0] else { return }
            for i in 0..<frameCount {
                dst[i] = Float(src[i]) / 32767.0
            }
        }

        return buffer
    }

    // MARK: - Audio Session

    private func activateSession() {
        guard !sessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: .duckOthers)
            try session.setActive(true)
            sessionActive = true
            log("Audio session activated")
        } catch {
            log("Audio session error: \(error)")
        }
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        sessionActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        log("Audio session deactivated")
    }

    private func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            log("Engine restarted")
        } catch {
            log("Engine restart error: \(error)")
        }
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[AudioQueue] \(msg)")
        #endif
    }
}
