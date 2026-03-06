//
//  ContentView.swift
//  soundDapp
//
//  Детектор звонка двери — UI: включение/выключение, статус, разрешения.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DoorDetectorViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: viewModel.isListening ? "ear.trianglebadge.exclamationmark.fill" : "ear.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(viewModel.isListening ? .orange : .secondary)

                Text(viewModel.isListening ? "Слушаю..." : "Детектор звонка двери")
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let lastDetected = viewModel.lastDetectedTime {
                    Label("Последнее срабатывание: \(lastDetected)", systemImage: "bell.badge.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Button {
                    viewModel.toggleListening()
                } label: {
                    Label(
                        viewModel.isListening ? "Остановить" : "Включить детектор",
                        systemImage: viewModel.isListening ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isListening ? .red : .green)
                .disabled(viewModel.isBusy)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("Звонок двери")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task {
            await viewModel.setupPermissions()
        }
    }
}

#Preview {
    ContentView()
}
