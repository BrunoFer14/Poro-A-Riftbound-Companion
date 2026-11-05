import SwiftUI

struct CounterView: View {
    let cardCache: CardCache

    @State private var player1Legend: Card?
    @State private var player1Points = 0
    @State private var player2Legend: Card?
    @State private var player2Points = 0
    @State private var gameStarted = false
    @State private var pickingFor: Int? // 1 or 2
    @State private var bestOf = 1 // 1 or 3
    @State private var player1Wins = 0
    @State private var player2Wins = 0
    @State private var seriesOver = false
    @State private var timeRemaining = 3600
    @State private var timerTask: Task<Void, Never>?

    private var timerText: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var timerColor: Color {
        if timeRemaining <= 0 { return .red }
        if timeRemaining <= 300 { return .orange }
        return .white.opacity(0.8)
    }

    private var legends: [Card] {
        var seen = Set<String>()
        return cardCache.allCards
            .filter { $0.classification.type == "Legend" && !$0.metadata.alternateArt && !$0.metadata.overnumbered }
            .sorted { $0.name < $1.name }
            .filter { seen.insert($0.name).inserted }
    }

    private var winsNeeded: Int { bestOf == 3 ? 2 : 1 }

    var body: some View {
        if gameStarted, let legend1 = player1Legend, let legend2 = player2Legend {
            gameView(legend1: legend1, legend2: legend2)
                .ignoresSafeArea()
                .statusBarHidden()
                .toolbar(.hidden, for: .tabBar)
                .onChange(of: player1Points) { checkGameWin() }
                .onChange(of: player2Points) { checkGameWin() }
        } else {
            NavigationStack {
                if !cardCache.isLoaded {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("A carregar legends...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Contador")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    selectionView
                        .navigationTitle("Contador")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar(.visible, for: .tabBar)
            .task { await cardCache.loadIfNeeded() }
        }
    }

    // MARK: - Legend Selection

    private var selectionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Seleciona as Legends")
                .font(.title3.bold())

            legendSlot(label: "Jogador 1", card: player1Legend) {
                pickingFor = 1
            }

            legendSlot(label: "Jogador 2", card: player2Legend) {
                pickingFor = 2
            }

            VStack(spacing: 8) {
                Text("Formato")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Picker("Formato", selection: $bestOf) {
                    Text("Best of 1").tag(1)
                    Text("Best of 3").tag(3)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            Spacer()

            Button {
                player1Wins = 0
                player2Wins = 0
                player1Points = 0
                player2Points = 0
                seriesOver = false
                timeRemaining = 3600
                gameStarted = true
            } label: {
                Text("Começar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(player1Legend == nil || player2Legend == nil)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .sheet(item: $pickingFor) { player in
            NavigationStack {
                LegendGridPicker(
                    legends: legends,
                    excluding: player == 1 ? player2Legend : player1Legend
                ) { selected in
                    if player == 1 {
                        player1Legend = selected
                    } else {
                        player2Legend = selected
                    }
                    pickingFor = nil
                }
                .navigationTitle("Escolher Legend")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            pickingFor = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    private func legendSlot(label: String, card: Card?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Button(action: action) {
                HStack(spacing: 12) {
                    if let card {
                        CardImageView(url: card.media.imageUrl, width: 50, height: 70)
                        VStack(alignment: .leading) {
                            Text(card.name)
                                .font(.subheadline.bold())
                            Text(card.classification.domain.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "person.crop.rectangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Escolher Legend")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Game View

    private func gameView(legend1: Card, legend2: Card) -> some View {
        VStack(spacing: 0) {
            // Player 2 (top — rotated for opponent)
            PlayerCounterHalf(legend: legend2, points: $player2Points, disabled: seriesOver)
                .rotationEffect(.degrees(180))
                .clipped()

            // Center bar
            centerBar
                .zIndex(1)

            // Player 1 (bottom)
            PlayerCounterHalf(legend: legend1, points: $player1Points, disabled: seriesOver)
                .clipped()
        }
        .background(.black)
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timeRemaining -= 1
            }
        }
    }

    private var centerBar: some View {
        HStack(spacing: 0) {
            // Player 2 name + score (rotated for opponent)
            Text("\(player2Legend?.name ?? ""): \(player2Wins)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity)

            // Controls + Timer
            VStack(spacing: 2) {
                Text(timerText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(timerColor)
                    .animation(.easeInOut(duration: 0.3), value: timerColor)

                HStack(spacing: 20) {
                    Button {
                        timerTask?.cancel()
                        gameStarted = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }

                    Button {
                        player1Points = 0
                        player2Points = 0
                        timeRemaining = 3600
                        startTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
            }

            // Player 1 name + score
            Text("\(player1Legend?.name ?? ""): \(player1Wins)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(height: 60)
        .background(.black)
    }

    // MARK: - Game Logic

    private func checkGameWin() {
        guard !seriesOver else { return }

        if player1Points >= 8 {
            player1Wins += 1
            if player1Wins >= winsNeeded {
                seriesOver = true
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    player1Points = 0
                    player2Points = 0
                }
            }
        } else if player2Points >= 8 {
            player2Wins += 1
            if player2Wins >= winsNeeded {
                seriesOver = true
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    player1Points = 0
                    player2Points = 0
                }
            }
        }
    }
}

// MARK: - Int + Identifiable for sheet(item:)

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Legend Grid Picker

private struct LegendGridPicker: View {
    let legends: [Card]
    let excluding: Card?
    let onSelect: (Card) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(legends.filter { $0.id != excluding?.id }) { legend in
                    Button {
                        onSelect(legend)
                    } label: {
                        VStack(spacing: 4) {
                            CardImageView(url: legend.media.imageUrl, width: 90, height: 126)
                            Text(legend.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
