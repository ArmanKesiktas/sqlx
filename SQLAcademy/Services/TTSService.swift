import Foundation

/// Pure Gemini TTS API client — fully nonisolated & Sendable.
/// Handles retries, text cleaning, chunking, and duration calculation.
final class TTSService: Sendable {

    struct Config: Sendable {
        let apiKey: String
        let model: String
        let voiceName: String
        let sampleRate: Double
        let maxRetries: Int
        let timeoutSeconds: TimeInterval

        static let `default` = Config(
            apiKey: "AIzaSyDs4mIDWGpmn9bNiOWP6RrxiTUoQ76Idko",
            model: "gemini-2.5-flash-preview-tts",
            voiceName: "Kore",
            sampleRate: 24000,
            maxRetries: 2,
            timeoutSeconds: 15
        )
    }

    let config: Config

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - Public API

    /// Fetch TTS audio for text. Returns raw PCM Int16 data or nil.
    /// Retries up to `config.maxRetries` times with 500ms delay between attempts.
    func fetchAudio(for text: String) async -> Data? {
        let cleaned = Self.cleanForTTS(text)
        guard !cleaned.isEmpty else {
            log("Skip: empty text after cleaning")
            return nil
        }

        for attempt in 1...config.maxRetries {
            guard !Task.isCancelled else {
                log("Cancelled before attempt \(attempt)")
                return nil
            }

            log("Attempt \(attempt)/\(config.maxRetries) for: \"\(cleaned.prefix(60))...\"")

            if let data = await doFetch(text: cleaned) {
                let dur = duration(of: data)
                log("OK attempt \(attempt): \(data.count) bytes (\(String(format: "%.1f", dur))s)")
                return data
            }

            if attempt < config.maxRetries {
                log("Attempt \(attempt) failed, retrying in 500ms...")
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        log("All \(config.maxRetries) attempts failed")
        return nil
    }

    /// Split long text into speakable chunks at sentence boundaries.
    /// Short text (<150 chars) is returned as a single chunk.
    func chunkText(_ text: String) -> [String] {
        let cleaned = Self.cleanForTTS(text)
        guard !cleaned.isEmpty else { return [] }
        guard cleaned.count >= 150 else { return [cleaned] }

        var chunks: [String] = []
        var remaining = cleaned[cleaned.startIndex...]

        while !remaining.isEmpty {
            if remaining.count <= 200 {
                let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { chunks.append(trimmed) }
                break
            }

            let maxLook = min(250, remaining.count)
            let searchEnd = remaining.index(remaining.startIndex, offsetBy: maxLook)
            let window = remaining[remaining.startIndex..<searchEnd]

            var splitAt: String.Index?

            // 1) sentence enders
            for ender in [". ", "! ", "? ", ".\n", "!\n", "?\n"] {
                if let r = window.range(of: ender, options: .backwards),
                   remaining.distance(from: remaining.startIndex, to: r.upperBound) >= 30 {
                    splitAt = r.upperBound
                    break
                }
            }

            // 2) clause enders
            if splitAt == nil {
                for ender in [", ", "; "] {
                    if let r = window.range(of: ender, options: .backwards),
                       remaining.distance(from: remaining.startIndex, to: r.upperBound) >= 30 {
                        splitAt = r.upperBound
                        break
                    }
                }
            }

            // 3) last space
            if splitAt == nil, let sp = window.lastIndex(of: " ") {
                splitAt = remaining.index(after: sp)
            }

            if let idx = splitAt {
                let chunk = String(remaining[remaining.startIndex..<idx])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !chunk.isEmpty { chunks.append(chunk) }
                remaining = remaining[idx...]
            } else {
                let trimmed = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { chunks.append(trimmed) }
                break
            }
        }

        log("Chunked into \(chunks.count) pieces: \(chunks.map { "\($0.count) chars" })")
        return chunks
    }

    /// Duration of PCM Int16 data in seconds.
    func duration(of data: Data) -> TimeInterval {
        let frames = data.count / 2
        guard frames > 0 else { return 0 }
        return TimeInterval(frames) / config.sampleRate
    }

    // MARK: - Text Cleaning

    private static let markerPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\[[A-Z_]+\]"#)
    }()

    static func cleanForTTS(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = markerPattern?
            .stringByReplacingMatches(in: text, range: range, withTemplate: "") ?? text
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Networking

    private func doFetch(text: String) async -> Data? {
        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(config.model):generateContent?key=\(config.apiKey)"
        ) else {
            log("Bad URL")
            return nil
        }

        let body: [String: Any] = [
            "contents": [["parts": [["text": text]]]],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": ["voiceName": config.voiceName]
                    ]
                ]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            log("JSON serialization failed")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = config.timeoutSeconds

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                log("No HTTP response object")
                return nil
            }

            guard (200..<300).contains(http.statusCode) else {
                log("HTTP \(http.statusCode)")
                #if DEBUG
                if let bodyStr = String(data: data, encoding: .utf8) {
                    log("Body: \(bodyStr.prefix(400))")
                }
                #endif
                return nil
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = json["candidates"] as? [[String: Any]],
                let content = candidates.first?["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let inlineData = parts.first?["inlineData"] as? [String: Any],
                let b64 = inlineData["data"] as? String,
                let audioData = Data(base64Encoded: b64),
                audioData.count > 100
            else {
                log("Failed to parse audio from JSON response")
                #if DEBUG
                if let bodyStr = String(data: data, encoding: .utf8) {
                    log("Raw response: \(bodyStr.prefix(500))")
                }
                #endif
                return nil
            }

            return audioData

        } catch is CancellationError {
            log("Request cancelled")
            return nil
        } catch {
            log("Network error: \(error.localizedDescription)")
            return nil
        }
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[TTSService] \(msg)")
        #endif
    }
}
