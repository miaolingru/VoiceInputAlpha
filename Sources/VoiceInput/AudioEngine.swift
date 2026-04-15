import AVFoundation
import Speech

final class AudioEngineController {
    let engine = AVAudioEngine()
    private var rmsHandler: ((Float) -> Void)?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    func start(rmsHandler: @escaping (Float) -> Void, recognitionRequest: SFSpeechAudioBufferRecognitionRequest?) {
        self.rmsHandler = rmsHandler
        self.recognitionRequest = recognitionRequest

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Feed speech recognizer
            self.recognitionRequest?.append(buffer)
            // Compute RMS
            let rms = self.computeRMS(buffer: buffer)
            self.rmsHandler?(rms)
        }

        do {
            try engine.start()
        } catch {
            print("[AudioEngine] Failed to start: \(error)")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        rmsHandler = nil
        recognitionRequest = nil
    }

    private func computeRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        let data = channelData[0]
        for i in 0..<count {
            let sample = data[i]
            sum += sample * sample
        }
        let rms = sqrtf(sum / Float(count))
        // Convert to 0-1 range with some amplification
        let normalized = min(rms * 5.0, 1.0)
        return normalized
    }
}
