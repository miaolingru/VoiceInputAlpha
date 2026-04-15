import AVFoundation
import Speech
import Accelerate

final class AudioEngineController {
    let engine = AVAudioEngine()
    private var bandsHandler: (([Float]) -> Void)?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    // FFT
    private let fftSize = 2048
    private var fftSetup: FFTSetup?
    private var hannWindow: [Float] = []
    private var sampleBuffer: [Float] = []

    // 频段频率范围（Hz），根据实际采样率动态计算 bin 索引
    private let bandFreqRanges: [(Float, Float)] = [
        (80,   300),   // 低频  — 胸腔共鸣/基频
        (300,  800),   // 中低  — 元音基音
        (800,  2500),  // 中频  — 语音主体
        (2500, 5000),  // 中高  — 辅音清晰度
        (5000, 10000), // 高频  — 齿音/气息
    ]

    init() {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        hannWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        if let s = fftSetup { vDSP_destroy_fftsetup(s) }
    }

    func start(bandsHandler: @escaping ([Float]) -> Void,
               recognitionRequest: SFSpeechAudioBufferRecognitionRequest?) {
        self.bandsHandler = bandsHandler
        self.recognitionRequest = recognitionRequest
        sampleBuffer = []

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)

            if let channelData = buffer.floatChannelData {
                let count = Int(buffer.frameLength)
                self.sampleBuffer.append(
                    contentsOf: UnsafeBufferPointer(start: channelData[0], count: count)
                )
            }

            // 攒够 fftSize 后做 FFT，50% 重叠提高时间分辨率
            while self.sampleBuffer.count >= self.fftSize {
                let chunk = Array(self.sampleBuffer.prefix(self.fftSize))
                self.sampleBuffer.removeFirst(self.fftSize / 2)
                let bands = self.computeBands(samples: chunk, sampleRate: sampleRate)
                self.bandsHandler?(bands)
            }
        }

        do { try engine.start() }
        catch { print("[AudioEngine] 启动失败: \(error)") }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        bandsHandler = nil
        recognitionRequest = nil
        sampleBuffer = []
    }

    // MARK: - FFT

    private func computeBands(samples: [Float], sampleRate: Float) -> [Float] {
        guard let fftSetup, samples.count == fftSize else {
            return [Float](repeating: 0, count: 5)
        }

        let halfSize = fftSize / 2
        let log2n = vDSP_Length(log2(Float(fftSize)))

        // 加汉宁窗
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, hannWindow, 1, &windowed, 1, vDSP_Length(fftSize))

        // 实数 FFT
        var real = [Float](repeating: 0, count: halfSize)
        var imag = [Float](repeating: 0, count: halfSize)

        let bands: [Float] = real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!,
                                            imagp: imagBuf.baseAddress!)

                // 把 real 信号打包成复数格式
                windowed.withUnsafeBytes { rawPtr in
                    rawPtr.withMemoryRebound(to: DSPComplex.self) { complexPtr in
                        vDSP_ctoz(complexPtr.baseAddress!, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }

                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                // 幅度（不是功率），正确归一化：除以 N 再取 sqrt
                var mags = [Float](repeating: 0, count: halfSize)
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(halfSize))
                // vDSP_zvabs 输出是 sqrt(r²+i²)，但 zrip 的输出在 0 号位不含虚部
                // 归一化：除以 (fftSize/2)
                var norm = Float(halfSize)
                vDSP_vsdiv(mags, 1, &norm, &mags, 1, vDSP_Length(halfSize))

                // 按频率范围切分频段，取均值后转 dB，映射到 0-1
                let freqPerBin = sampleRate / Float(self.fftSize)
                return self.bandFreqRanges.map { (loFreq, hiFreq) in
                    let loIdx = max(1, Int(loFreq / freqPerBin))
                    let hiIdx = min(halfSize - 1, Int(hiFreq / freqPerBin))
                    guard loIdx < hiIdx else { return Float(0) }

                    let slice = mags[loIdx...hiIdx]
                    let mean = slice.reduce(0, +) / Float(slice.count)

                    // 对数映射：-70dB → 0，-10dB → 1（语音典型范围）
                    let dB = 20.0 * log10(max(mean, 1e-7))
                    let normalized = (dB + 70.0) / 60.0
                    return max(0, min(1, normalized))
                }
            }
        }

        return bands
    }
}
