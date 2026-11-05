import SwiftUI

// MARK: - Scanner Mode

enum ScannerMode {
    case collection
    case sell

    var title: String {
        switch self {
        case .collection: "Coleção"
        case .sell: "Vender"
        }
    }

    var icon: String {
        switch self {
        case .collection: "heart.rectangle.fill"
        case .sell: "tag.fill"
        }
    }
}

private let knownSetIds: Set<String> = ["OGN", "VEN", "OPP", "PR", "SFD", "JDG", "UNL", "OGS"]

// MARK: - CardScannerView

struct CardScannerView: View {
    let collectionStore: CollectionStore
    let cardCache: CardCache
    let authService: AuthService

    @State private var cameraManager = CameraManager()
    @State private var isProcessing = false

    // Match state
    @State private var confirmedMatch: CardMatch?
    @State private var pendingCode: String?
    @State private var pendingFrames = 0

    // Lazy per-set cache
    @State private var setCards: [String: [Card]] = [:]
    @State private var loadingSet: String?

    // Mode + foil
    @State private var scannerMode: ScannerMode?
    @State private var showModeSheet = false
    @State private var isFoilMode = false

    // Sell
    @State private var showCreateListing = false
    @State private var sellVM = MarketplaceViewModel()

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
                    cameraLayer
                } else {
                    ProgressView("A pedir acesso à câmara...")
                }
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                showModeSheet = true
                if cameraManager.permissionGranted { startCamera() }
                else { cameraManager.requestPermission() }
            }
            .onChange(of: cameraManager.permissionGranted) {
                if cameraManager.permissionGranted { startCamera() }
            }
            .onDisappear {
                cameraManager.stopSession()
                cameraManager.onFrameCaptured = nil
                reset()
                scannerMode = nil
            }
            .sheet(isPresented: $showModeSheet) {
                modeSheet
                    .interactiveDismissDisabled(scannerMode == nil)
                    .presentationDetents([.height(220)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreateListing, onDismiss: reset) {
                if let match = confirmedMatch {
                    CreateListingView(authService: authService, cardCache: cardCache, viewModel: sellVM, preselectedCard: match.card)
                }
            }
        }
    }

    // MARK: - Camera

    private var cameraLayer: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            if confirmedMatch == nil {
                VStack {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                        .padding(10)
                        .background(.black.opacity(0.5), in: .circle)
                    Spacer()
                }
                .padding(.top, 16)
            }

            if let match = confirmedMatch, scannerMode == .collection {
                matchOverlay(match)
            }
        }
    }

    // MARK: - Match Overlay

    private func matchOverlay(_ match: CardMatch) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                CardImageView(url: match.card.media.imageUrl, width: 80, height: 112)

                VStack(alignment: .leading, spacing: 6) {
                    Text(match.card.name).font(.headline).lineLimit(2)

                    HStack(spacing: 4) {
                        Text(match.card.set.label)
                        Text("•")
                        Text("\(Int(match.confidence * 100))%")
                            .bold()
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Normal
                    qtyRow(
                        qty: collectionStore.quantity(for: match.card.id),
                        minus: { collectionStore.decrement(match.card) },
                        plus: { collectionStore.increment(match.card) },
                        tint: .accentColor, big: true
                    )
                    // Foil
                    foilRow(
                        qty: collectionStore.foilQuantity(for: match.card.id),
                        minus: { collectionStore.decrementFoil(match.card) },
                        plus: { collectionStore.incrementFoil(match.card) }
                    )
                    // Promo
                    promoRow(
                        qty: collectionStore.promoQuantity(for: match.card.id),
                        minus: { collectionStore.decrementPromo(match.card) },
                        plus: { collectionStore.incrementPromo(match.card) }
                    )
                }
                Spacer()
            }

            Button { withAnimation { reset() } } label: {
                Text("OK").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func qtyRow(qty: Int, minus: @escaping () -> Void, plus: @escaping () -> Void, tint: Color, big: Bool) -> some View {
        HStack(spacing: 16) {
            Button(action: minus) {
                Image(systemName: "minus.circle.fill")
                    .font(big ? .title2 : .body)
                    .foregroundStyle(qty > 0 ? .red : .secondary.opacity(0.3))
            }.buttonStyle(.plain).disabled(qty <= 0)

            Text("×\(qty)")
                .font(big ? .title3.bold().monospacedDigit() : .subheadline.bold().monospacedDigit())
                .contentTransition(.numericText())
                .animation(.snappy, value: qty)
                .frame(minWidth: 30)

            Button(action: plus) {
                Image(systemName: "plus.circle.fill")
                    .font(big ? .title2 : .body)
                    .foregroundStyle(tint)
            }.buttonStyle(.plain)
        }
    }

    private func foilRow(qty: Int, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Button(action: minus) {
                Image(systemName: "minus.circle.fill").font(.body)
                    .foregroundStyle(qty > 0 ? .red : .secondary.opacity(0.3))
            }.buttonStyle(.plain).disabled(qty <= 0)

            HStack(spacing: 2) {
                Text("✦").font(.caption.bold()).foregroundStyle(.purple)
                Text("\(qty)").font(.subheadline.bold().monospacedDigit())
                    .contentTransition(.numericText()).animation(.snappy, value: qty)
            }.frame(minWidth: 30)

            Button(action: plus) {
                Image(systemName: "plus.circle.fill").font(.body).foregroundStyle(.purple)
            }.buttonStyle(.plain)
        }
    }

    private func promoRow(qty: Int, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Button(action: minus) {
                Image(systemName: "minus.circle.fill").font(.body)
                    .foregroundStyle(qty > 0 ? .red : .secondary.opacity(0.3))
            }.buttonStyle(.plain).disabled(qty <= 0)

            HStack(spacing: 2) {
                Text("P").font(.caption.bold()).foregroundStyle(.orange)
                Text("\(qty)").font(.subheadline.bold().monospacedDigit())
                    .contentTransition(.numericText()).animation(.snappy, value: qty)
            }.frame(minWidth: 30)

            Button(action: plus) {
                Image(systemName: "plus.circle.fill").font(.body).foregroundStyle(.orange)
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                if scannerMode == .collection {
                    Button { withAnimation { isFoilMode.toggle() } } label: {
                        Text("✦").font(.body.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(
                                isFoilMode
                                    ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.secondary.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                                in: .capsule
                            )
                            .foregroundStyle(isFoilMode ? .white : .secondary)
                    }.buttonStyle(.plain)
                }
                if let mode = scannerMode {
                    Button { showModeSheet = true } label: {
                        Label(mode.title, systemImage: mode.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: .capsule)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Mode Sheet

    private var modeSheet: some View {
        VStack(spacing: 20) {
            Text("Modo de Scanner").font(.headline).padding(.top, 12)
            HStack(spacing: 16) {
                modeBtn(.collection)
                modeBtn(.sell)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    private func modeBtn(_ mode: ScannerMode) -> some View {
        Button {
            scannerMode = mode
            showModeSheet = false
        } label: {
            VStack(spacing: 10) {
                Image(systemName: mode.icon).font(.title2)
                Text(mode.title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(scannerMode == mode ? Color.accentColor : Color.secondary.opacity(0.12), in: .rect(cornerRadius: 16))
            .foregroundStyle(scannerMode == mode ? .white : .primary)
        }.buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func startCamera() {
        setupRecognition()
        cameraManager.startSession()
    }

    private func reset() {
        confirmedMatch = nil
        pendingCode = nil
        pendingFrames = 0
    }

    // MARK: - Recognition

    private func setupRecognition() {
        cameraManager.onFrameCaptured = { sampleBuffer in
            Task { @MainActor in
                guard !isProcessing, confirmedMatch == nil else { return }
                isProcessing = true
                let addAsFoil = isFoilMode
                let cachedSets = setCards

                let buffer = sampleBuffer
                Task.detached {
                    nonisolated(unsafe) let buf = buffer

                    // 1. OCR (dual-pass: fast + accurate)
                    let texts = CardRecognitionService.recognizeText(from: buf)

                    // 2. Extract set+number codes
                    let codes = CardRecognitionService.extractCodes(from: texts, knownSetIds: knownSetIds)
                    guard let best = codes.max(by: { ($0.hasTotal ? 1 : 0) < ($1.hasTotal ? 1 : 0) }) else {
                        await MainActor.run { decay(); isProcessing = false }
                        return
                    }

                    // 3. Resolve card from set (lazy load)
                    let cards: [Card]
                    if let c = cachedSets[best.setId] { cards = c }
                    else { cards = await fetchSet(best.setId) }

                    let found = CardRecognitionService.findCard(
                        collectorNumber: best.collectorNumber,
                        suffix: best.suffix,
                        in: cards
                    )

                    // 4. Multi-frame confirm
                    await MainActor.run {
                        if let card = found {
                            let key = "\(best.setId)-\(best.collectorNumber)"
                            if key == pendingCode {
                                pendingFrames += 1
                                if pendingFrames >= 2 {
                                    let conf = best.hasTotal ? 0.98 : 0.95
                                    withAnimation {
                                        confirmedMatch = CardMatch(card: card, confidence: conf)
                                    }
                                    if scannerMode == .collection {
                                        if addAsFoil { collectionStore.incrementFoil(card) }
                                        else { collectionStore.increment(card) }
                                    } else if scannerMode == .sell {
                                        showCreateListing = true
                                    }
                                    pendingCode = nil
                                    pendingFrames = 0
                                }
                            } else {
                                pendingCode = key
                                pendingFrames = 1
                            }
                        } else {
                            decay()
                        }
                        isProcessing = false
                    }
                }
            }
        }
    }

    private func decay() {
        if pendingFrames > 0 {
            pendingFrames -= 1
            if pendingFrames == 0 { pendingCode = nil }
        }
    }

    // MARK: - Fetch Set

    private func fetchSet(_ setId: String) async -> [Card] {
        if let c = await MainActor.run(body: { setCards[setId] }) { return c }
        if await MainActor.run(body: { loadingSet }) == setId {
            try? await Task.sleep(for: .milliseconds(500))
            return await MainActor.run { setCards[setId] ?? [] }
        }

        await MainActor.run { loadingSet = setId }
        defer { Task { @MainActor in loadingSet = nil } }

        await cardCache.loadIfNeeded()
        let all = cardCache.cards(forSetId: setId)
        await MainActor.run { setCards[setId] = all }
        return all
    }
}
