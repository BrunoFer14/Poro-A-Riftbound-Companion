import SwiftUI
import FirebaseAuth

struct CreateListingView: View {
    let authService: AuthService
    let cardCache: CardCache
    let viewModel: MarketplaceViewModel
    var preselectedCard: Card? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCard: Card? = nil
    @State private var condition: CardCondition = .nearMint
    @State private var priceText = ""
    @State private var quantity = 1
    @State private var description = ""
    @State private var pickedLocation: PickedLocation? = nil
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showCardPicker = false
    @State private var showLocationPicker = false
    @State private var cardSearchText = ""

    private var isValid: Bool {
        selectedCard != nil && priceDouble != nil && priceDouble! > 0
    }

    private var priceDouble: Double? {
        Double(priceText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Card picker
                Section("Carta") {
                    if let card = selectedCard {
                        HStack(spacing: 12) {
                            CardImageView(url: card.media.imageUrl, width: 48, height: 67)
                                .clipShape(.rect(cornerRadius: 4))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name).font(.headline)
                                Text(card.set.label).font(.caption).foregroundStyle(.secondary)
                                Text(card.classification.rarity).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Alterar") { showCardPicker = true }
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            showCardPicker = true
                        } label: {
                            Label("Escolher carta", systemImage: "rectangle.stack.badge.plus")
                        }
                    }
                }

                // Condition
                Section("Condição") {
                    Picker("Condição", selection: $condition) {
                        ForEach(CardCondition.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Price & quantity
                Section("Preço e Quantidade") {
                    HStack {
                        TextField("Preço (ex: 2.50)", text: $priceText)
                            .keyboardType(.decimalPad)
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
                    Stepper("Quantidade: \(quantity)", value: $quantity, in: 1...20)
                }

                // Location
                Section("Localização") {
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(Color.accentColor)
                            if let loc = pickedLocation {
                                Text(loc.name)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Escolher localização")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if pickedLocation != nil {
                                Button {
                                    pickedLocation = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Description (optional)
                Section("Nota (opcional)") {
                    TextField("Estado da carta, portes, etc.", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Novo Anúncio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar") {
                        Task { await submit() }
                    }
                    .disabled(!isValid || isSubmitting)
                    .overlay {
                        if isSubmitting { ProgressView().scaleEffect(0.8) }
                    }
                }
            }
            .sheet(isPresented: $showCardPicker) {
                CardPickerSheet(selectedCard: $selectedCard, cardCache: cardCache)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(pickedLocation: $pickedLocation)
            }
            .onAppear {
                if selectedCard == nil, let pre = preselectedCard {
                    selectedCard = pre
                }
            }
        }
    }

    private func submit() async {
        guard let card = selectedCard,
              let price = priceDouble,
              let uid = authService.currentUser?.uid,
              let sellerName = authService.displayName ?? authService.email
        else { return }

        isSubmitting = true
        errorMessage = nil

        let listing = Listing(
            id: UUID().uuidString,
            sellerId: uid,
            sellerName: sellerName,
            cardId: card.id,
            cardName: card.name,
            cardImageUrl: card.media.imageUrl,
            cardSet: card.set.label,
            cardRarity: card.classification.rarity,
            cardType: card.classification.type,
            price: price,
            condition: condition,
            quantity: quantity,
            description: description,
            location: pickedLocation?.name ?? "",
            latitude: pickedLocation?.latitude,
            longitude: pickedLocation?.longitude,
            createdAt: Date(),
            status: .active
        )

        do {
            try await viewModel.createListing(listing)
            dismiss()
        } catch {
            errorMessage = "Erro ao publicar: \(error.localizedDescription)"
            isSubmitting = false
        }
    }
}

// MARK: - Card Picker Sheet

private struct CardPickerSheet: View {
    @Binding var selectedCard: Card?
    let cardCache: CardCache
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [Card] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Group {
                if !hasSearched {
                    ContentUnavailableView(
                        "Pesquisa uma carta",
                        systemImage: "magnifyingglass",
                        description: Text("Escreve o nome da carta que queres vender.")
                    )
                } else if isSearching {
                    ProgressView("A pesquisar...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(results) { card in
                        Button {
                            selectedCard = card
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CardImageView(url: card.media.imageUrl, width: 40, height: 56)
                                    .clipShape(.rect(cornerRadius: 4))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(card.set.label) · \(card.classification.rarity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Escolher Carta")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Nome da carta...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onChange(of: searchText) {
                scheduleSearch()
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            results = []
            hasSearched = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        hasSearched = true
        await cardCache.loadIfNeeded()
        guard !Task.isCancelled else { isSearching = false; return }
        let q = query.trimmingCharacters(in: .whitespaces)
        results = cardCache.allCards.filter {
            $0.name.localizedCaseInsensitiveContains(q) &&
            !$0.metadata.alternateArt &&
            !$0.metadata.overnumbered
        }
        isSearching = false
    }
}
