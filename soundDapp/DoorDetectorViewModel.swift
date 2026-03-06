//
//  DoorDetectorViewModel.swift
//  soundDapp
//
//  Связывает SoundAnalyzerService и NotificationManager с UI.
//

import SwiftUI

@MainActor
final class DoorDetectorViewModel: ObservableObject {
    @Published var isListening = false
    @Published var isBusy = false
    @Published var statusMessage = "Нажмите «Включить детектор» и разрешите микрофон и уведомления."
    @Published var lastDetectedTime: String?
    @Published var showError = false
    @Published var errorMessage = ""

    private let soundAnalyzer = SoundAnalyzerService()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .short
        return f
    }()

    init() {
        soundAnalyzer.onDoorSoundDetected = { [weak self] in
            Task { @MainActor in
                self?.handleDoorSoundDetected()
            }
        }
    }

    func setupPermissions() async {
        let mic = await soundAnalyzer.requestMicrophonePermission()
        let notif = await NotificationManager.shared.requestAuthorization()

        if !mic {
            statusMessage = "Доступ к микрофону запрещён. Включите в Настройки → soundDapp."
            return
        }
        if !notif {
            statusMessage = "Уведомления запрещены. Включите в Настройки → soundDapp → Уведомления."
            return
        }
        statusMessage = "Разрешения получены. Включите детектор, чтобы слушать звонок/стук в дверь."
    }

    func toggleListening() {
        guard !isBusy else { return }
        isBusy = true

        if isListening {
            soundAnalyzer.stop()
            isListening = false
            statusMessage = "Детектор выключен."
        } else {
            do {
                try soundAnalyzer.start()
                isListening = true
                statusMessage = "Слушаю звонок и стук в дверь. Положите телефон на стол."
            } catch {
                errorMessage = "Не удалось запустить анализ: \(error.localizedDescription)"
                showError = true
            }
        }
        isBusy = false
    }

    private func handleDoorSoundDetected() {
        lastDetectedTime = dateFormatter.string(from: Date())
        NotificationManager.shared.sendDoorSoundNotification()
    }
}
