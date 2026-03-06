//
//  SoundAnalyzerService.swift
//  soundDapp
//
//  Детектор звонка/стука в дверь через Sound Analysis (SNAudioStreamAnalyzer + SNClassifySoundRequest).
//

import AVFoundation
import SoundAnalysis
import Foundation

/// Идентификаторы звуков из встроенной модели Apple (version1), релевантные для «кто-то в двери».
private enum DoorSoundIdentifier: String, CaseIterable {
    case doorBell = "door_bell"
    case knock = "knock"
    case doorSlam = "door_slam"
    case door = "door"
    case bell = "bell"

    var raw: String { rawValue }
}

/// Сервис анализа звука: микрофон → классификация → callback при обнаружении звонка/стука.
final class SoundAnalyzerService: NSObject {
    /// Минимальная уверенность (0...1) для срабатывания.
    var confidenceThreshold: Double = 0.6
    /// Минимальный интервал между срабатываниями (секунды), чтобы не спамить уведомлениями.
    var cooldownInterval: TimeInterval = 10.0

    /// Вызывается при обнаружении звука «звонок/стук в дверь» (на главном потоке).
    var onDoorSoundDetected: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var classifyRequest: SNClassifySoundRequest?
    private var lastDetectionTime: Date = .distantPast
    private let queue = DispatchQueue(label: "com.soundDapp.analysis")
    private var isRunning = false

    override init() {
        super.init()
    }

    /// Запрашивает доступ к микрофону и возвращает результат.
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Запускает прослушивание микрофона и анализ в реальном времени.
    func start() throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try session.setActive(true)

        guard let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else {
            throw AnalyzerError.classifierUnavailable
        }
        classifyRequest = request
        request.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 1000)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard let analyzer = try? SNAudioStreamAnalyzer(format: format) else {
            throw AnalyzerError.analyzerCreationFailed
        }
        streamAnalyzer = analyzer

        try analyzer.add(request, withObserver: self)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.queue.async {
                self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }

        try audioEngine.start()
        isRunning = true
    }

    /// Останавливает анализ и снимает тап с микрофона.
    func stop() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        streamAnalyzer = nil
        classifyRequest = nil
        isRunning = false
    }

    private func checkAndNotifyDoorSound() {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= cooldownInterval else { return }
        lastDetectionTime = now
        DispatchQueue.main.async { [weak self] in
            self?.onDoorSoundDetected?()
        }
    }

    enum AnalyzerError: Error {
        case classifierUnavailable
        case analyzerCreationFailed
    }
}

// MARK: - SNResultsObserving

extension SoundAnalyzerService: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult else { return }

        for id in DoorSoundIdentifier.allCases {
            guard let item = classification.classification(forIdentifier: id.raw),
                  item.confidence >= confidenceThreshold else { continue }
            checkAndNotifyDoorSound()
            return
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onDoorSoundDetected = nil
        }
    }

    func requestDidComplete(_ request: SNRequest) {}
}
