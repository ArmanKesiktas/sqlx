import AVFoundation
import Combine
import Foundation

/// Orchestrates TTS: text → TTSService (API) → AudioPlaybackQueue (playback).
///
/// Architecture:
/// - `TTSService` handles Gemini API calls with retry logic (nonisolated, Sendable).
/// - `AudioPlaybackQueue` handles AVAudioEngine + sequential buffer queue (@MainActor).
/// - `SpeechManager` ties them together, manages mute state, and provides the public API.
///
/// Key improvements over the previous implementation:
/// 1. No task-group race pattern — uses simple async/await with URLRequest timeout + retry.
/// 2. Audio engine format set once, never disconnect/reconnect.
/// 3. Audio session activated once per playback session, not per-buffer.
/// 4. Chunking at sentence boundaries for long text — first chunk plays sooner.
/// 5. Deduplication: tracks spoken text hashes to prevent replaying same content.
/// 6. Extensive debug logging at every stage.
@MainActor
final class SpeechManager: ObservableObject {

    static let shared = SpeechManager()

    // MARK: - Published State

    @Published var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "tts.muted")
            if isMuted { stop() }
        }
    }

    /// True while any audio buffer is playing.
    @Published private(set) var isSpeaking = false

    // MARK: - Components

    let ttsService = TTSService()
    private let audioQueue = AudioPlaybackQueue()
    private var speakingObserver: AnyCancellable?

    // MARK: - Internal State

    private var currentTask: Task<Void, Never>?
    private var spokenHashes: Set<Int> = []

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: "tts.muted")

        // Forward audioQueue.isPlaying → self.isSpeaking
        speakingObserver = audioQueue.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.isSpeaking = playing
            }
    }

    // MARK: - Public API

    /// Speak text using TTS. Stops any current playback first.
    /// Text is chunked at sentence boundaries; first chunk starts playing
    /// as soon as its audio is fetched (remaining chunks stream in).
    func speak(text: String, languageCode: String = "tr-TR") {
        guard !isMuted else {
            log("Muted — skipping speak")
            return
        }

        let cleaned = TTSService.cleanForTTS(text)
        guard !cleaned.isEmpty else {
            log("Empty text after cleaning — skipping")
            return
        }

        let textHash = cleaned.hashValue
        guard !spokenHashes.contains(textHash) else {
            log("Already spoken this text — skipping duplicate")
            return
        }

        stop()
        spokenHashes.insert(textHash)

        log("speak() called: \"\(cleaned.prefix(80))...\"")

        currentTask = Task {
            let chunks = ttsService.chunkText(cleaned)
            log("Split into \(chunks.count) chunk(s)")

            for (i, chunk) in chunks.enumerated() {
                guard !Task.isCancelled else {
                    log("Cancelled at chunk \(i + 1)/\(chunks.count)")
                    return
                }

                log("Fetching chunk \(i + 1)/\(chunks.count): \"\(chunk.prefix(50))...\"")
                guard let audioData = await ttsService.fetchAudio(for: chunk) else {
                    log("Chunk \(i + 1) fetch failed — skipping")
                    continue
                }

                guard !Task.isCancelled else { return }
                audioQueue.enqueue(audioData)
            }
        }
    }

    /// Pre-fetch TTS audio without playing. Returns (pcmData, duration) or nil.
    /// Call from ViewModel to fetch audio during skeleton loading.
    func prefetchAudio(for text: String) async -> (data: Data, duration: TimeInterval)? {
        guard !isMuted else { return nil }

        let cleaned = TTSService.cleanForTTS(text)
        guard !cleaned.isEmpty else { return nil }

        log("prefetchAudio: \"\(cleaned.prefix(60))...\"")

        // For prefetch, send full text (no chunking) so we get exact duration for animation sync
        guard let data = await ttsService.fetchAudio(for: cleaned) else {
            log("prefetchAudio failed")
            return nil
        }

        let dur = ttsService.duration(of: data)
        log("prefetchAudio OK: \(data.count) bytes, \(String(format: "%.1f", dur))s")
        return (data, dur)
    }

    /// Play previously fetched PCM data immediately. Stops current playback.
    func playPreparedAudio(_ data: Data) {
        guard !isMuted else { return }
        stop()

        let textHash = data.hashValue
        spokenHashes.insert(textHash)

        log("playPreparedAudio: \(data.count) bytes")
        audioQueue.enqueue(data)
    }

    /// Stop all playback and cancel pending fetches.
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        audioQueue.stopAndClear()
    }

    /// Reset deduplication tracking (call when a new conversation turn starts).
    func resetSpokenTracking() {
        spokenHashes.removeAll()
        log("Spoken tracking reset")
    }

    /// Duration of PCM Int16 data in seconds.
    func audioDuration(for data: Data) -> TimeInterval {
        ttsService.duration(of: data)
    }

    // MARK: - Convenience

    /// Clean text for TTS (remove markers, trim whitespace).
    static func cleanTextForTTS(_ text: String) -> String {
        TTSService.cleanForTTS(text)
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[SpeechManager] \(msg)")
        #endif
    }
}
