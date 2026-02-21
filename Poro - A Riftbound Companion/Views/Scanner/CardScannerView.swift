import SwiftUI

struct CardScannerView: View {
    let collectionStore: CollectionStore
    let cardCache: CardCache

    @State private var cameraManager = CameraManager()
    @State private var matches: [CardMatch] = []
    @State private var addedCard: Card?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraManager.permissionDenied {
                    ContentUnavailableView(
                        "Câmara não disponível",
                        systemImage: "camera.slash",
                        description: Text("Permite o acesso à câmara nas Definições para digitalizar cartas.")
                    )
                } else if cameraManager.permissionGranted {
                    cameraContent
                } else {
                    ProgressView("A pedir acesso à câmara...")
                }
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cameraManager.requestPermission()
            }
            .task {
                // Preload card cache for matching
                await cardCache.loadIfNeeded()
            }
            .onChange(of: cameraManager.permissionGranted) {
                if cameraManager.permissionGranted {
                    setupRecognition()
                    cameraManager.startSession()
                }
            }
            .onDisappear {
                cameraManager.stopSession()
            }
        }
    }

    private var cameraContent: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            // Scanning indicator
            VStack {
                if isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("A procurar...")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: .capsule)
                }
                Spacer()
            }
            .padding(.top, 16)

            // Results overlay
            if !matches.isEmpty {
                matchesOverlay
            }

            // Added confirmation
            if let card = addedCard {
                addedConfirmation(card: card)
            }
        }
    }

    private var matchesOverlay: some View {
        VStack(spacing: 0) {
            ForEach(matches.prefix(3)) { match in
                matchRow(match)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.snappy, value: matches.map(\.card.id))
    }

    private func matchRow(_ match: CardMatch) -> some View {
        HStack(spacing: 12) {
            CardImageView(url: match.card.media.imageUrl, width: 45, height: 63)

            VStack(alignment: .leading, spacing: 4) {
                Text(match.card.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(match.card.set.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(Int(match.confidence * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(match.confidence >= 0.85 ? .green : .orange)
                }
            }

            Spacer()

            let qty = collectionStore.quantity(for: match.card.id)
            if qty > 0 {
                Text("×\(qty)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                collectionStore.increment(match.card)
                showAddedConfirmation(match.card)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func addedConfirmation(card: Card) -> some View {
        VStack {
            Spacer()
            Text("\(card.name) adicionada!")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.green, in: .capsule)
                .shadow(radius: 4)
                .padding(.bottom, matches.isEmpty ? 20 : 200)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.snappy, value: addedCard?.id)
    }

    private func showAddedConfirmation(_ card: Card) {
        addedCard = card
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { addedCard = nil }
        }
    }

    private func setupRecognition() {
        cameraManager.onFrameCaptured = { sampleBuffer in
            Task { @MainActor in
                guard !isProcessing, cardCache.isLoaded else { return }
                isProcessing = true
                let allCards = cardCache.allCards

                let buffer = sampleBuffer
                Task.detached {
                    nonisolated(unsafe) let buf = buffer
                    let texts = CardRecognitionService.recognizeText(from: buf)
                    let results = CardRecognitionService.matchCards(texts: texts, against: allCards)

                    await MainActor.run {
                        withAnimation {
                            matches = results
                        }
                        isProcessing = false
                    }
                }
            }
        }
    }
}
