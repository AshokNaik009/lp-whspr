import AVFoundation

/// Keeps the microphone engine running for the whole session (so the app stays alive in the background)
/// and only buffers 16 kHz mono samples while `isRecording` is on.
final class AudioCapture {
    static let sampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: AudioCapture.sampleRate, channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private var recording = false
    private var lastTick = Date.distantPast

    /// Called roughly once per second from the audio thread while the engine runs.
    var onTick: (() -> Void)?
    /// RMS level (0...1) of the latest buffer while recording, called on the audio thread.
    var onLevel: ((Float) -> Void)?

    var isRunning: Bool { engine.isRunning }

    var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }
        return recording
    }

    func startEngine() throws {
        guard !engine.isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        lock.lock()
        recording = false
        samples.removeAll()
        lock.unlock()
    }

    func beginRecording() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        recording = true
        lock.unlock()
    }

    /// Stops buffering and returns the captured 16 kHz mono samples.
    func endRecording() -> [Float] {
        lock.lock()
        recording = false
        let captured = samples
        samples.removeAll()
        lock.unlock()
        return captured
    }

    private func handle(_ buffer: AVAudioPCMBuffer) {
        let now = Date()
        if now.timeIntervalSince(lastTick) >= 1 {
            lastTick = now
            onTick?()
        }

        guard isRecording, let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = output.floatChannelData?[0] else { return }
        let chunk = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))

        var sum: Float = 0
        for s in chunk { sum += s * s }
        onLevel?(chunk.isEmpty ? 0 : min(1, sqrt(sum / Float(chunk.count)) * 8))

        lock.lock()
        if recording { samples.append(contentsOf: chunk) }
        lock.unlock()
    }
}
