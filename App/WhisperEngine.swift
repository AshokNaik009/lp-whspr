import Foundation
import whisper

enum WhisperEngineError: LocalizedError {
    case modelLoadFailed(String)
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let name): return "Could not load the Whisper model \(name)."
        case .transcriptionFailed: return "Whisper failed to transcribe the audio."
        }
    }
}

struct WhisperResult {
    var text: String
    /// Mean probability of the decoded text tokens (0...1).
    var confidence: Float
    /// Highest no-speech probability across segments (0...1).
    var noSpeechProbability: Float
}

/// whisper.cpp wrapper. The C context is not thread-safe, so all access goes through this actor.
actor WhisperEngine {
    static let shared = WhisperEngine()

    private var context: OpaquePointer?
    private var loadedPath: String?
    private var loadedWithGPU = false

    deinit {
        if let context { whisper_free(context) }
    }

    /// iOS does not allow Metal work from a backgrounded app, so callers pass `useGPU: false`
    /// when transcribing while the user is in another app.
    func load(modelAt url: URL, useGPU: Bool) throws {
        #if targetEnvironment(simulator)
        let gpu = false
        #else
        let gpu = useGPU
        #endif
        if loadedPath == url.path, loadedWithGPU == gpu, context != nil { return }
        unload()
        var params = whisper_context_default_params()
        params.use_gpu = gpu
        params.flash_attn = gpu
        guard let ctx = whisper_init_from_file_with_params(url.path, params) else {
            throw WhisperEngineError.modelLoadFailed(url.lastPathComponent)
        }
        context = ctx
        loadedPath = url.path
        loadedWithGPU = gpu
    }

    func unload() {
        if let context { whisper_free(context) }
        context = nil
        loadedPath = nil
    }

    func transcribe(samples input: [Float], language: String, prompt: String?) throws -> WhisperResult {
        guard let context else { throw WhisperEngineError.transcriptionFailed }

        var samples = input
        let minimum = Int(AudioCapture.sampleRate * 1.1)
        if samples.count < minimum {
            samples.append(contentsOf: [Float](repeating: 0, count: minimum - samples.count))
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_timestamps = true
        params.single_segment = false
        params.no_context = true
        params.suppress_blank = true
        params.detect_language = false
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))

        let isMultilingual = whisper_is_multilingual(context) != 0
        let requested = language.isEmpty ? "auto" : language
        let languageCString = strdup(isMultilingual ? requested : "en")
        let promptCString = prompt.flatMap { $0.isEmpty ? nil : strdup($0) }
        defer {
            free(languageCString)
            if let promptCString { free(promptCString) }
        }
        params.language = UnsafePointer(languageCString)
        if let promptCString { params.initial_prompt = UnsafePointer(promptCString) }

        whisper_reset_timings(context)
        let status = samples.withUnsafeBufferPointer { buffer in
            whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
        }
        guard status == 0 else { throw WhisperEngineError.transcriptionFailed }

        let firstSpecialToken = whisper_token_eot(context)
        var text = ""
        var probabilitySum: Float = 0
        var tokenCount = 0
        var noSpeech: Float = 0
        for segment in 0..<whisper_full_n_segments(context) {
            if let segmentText = whisper_full_get_segment_text(context, segment) {
                text += String(cString: segmentText)
            }
            noSpeech = max(noSpeech, whisper_full_get_segment_no_speech_prob(context, segment))
            for token in 0..<whisper_full_n_tokens(context, segment) {
                guard whisper_full_get_token_id(context, segment, token) < firstSpecialToken else { continue }
                probabilitySum += whisper_full_get_token_p(context, segment, token)
                tokenCount += 1
            }
        }
        let confidence = tokenCount > 0 ? probabilitySum / Float(tokenCount) : 0
        return WhisperResult(text: text, confidence: confidence, noSpeechProbability: noSpeech)
    }
}
