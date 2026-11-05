import SwiftUI
import FirebaseAuth

struct MarketplaceView: View {
    let authService: AuthService
    let collectionStore: CollectionStore
    let cardCache: CardCache

    @State private var viewModel = MarketplaceViewModel()
    @State private var selectedTab: MarketplaceTab = .browse
    @State private var showCreateListing = false

    enum MarketplaceTab: String, CaseIterable {
        case browse = "Explorar"
        case myListings = "Os Meus"
        case messages = "Mensagens"
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isLoggedIn {
                    notLoggedInView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Mercado")
            .toolbar {
                if authService.isLoggedIn && selectedTab == .browse {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateListing = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView(
                    authService: authService,
                    cardCache: cardCache,
                    viewModel: viewModel
                )
            }
            .task {
                if authService.isLoggedIn {
                    let uid = authService.currentUser?.uid ?? ""
                    viewModel.setup(userId: uid)
                    viewModel.listenToConversations(userId: uid)
                    await viewModel.loadListings()
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(MarketplaceTab.allCases, id: \.self) { tab in
                    if tab == .messages {
                        Label(tab.rawValue, systemImage: viewModel.totalUnread > 0 ? "message.badge.filled.fill" : "message")
                            .tag(tab)
                    } else {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case .browse:
                BrowseListingsView(viewModel: viewModel, authService: authService)
            case .myListings:
                MyListingsView(viewModel: viewModel, authService: authService)
            case .messages:
                MessagesListView(viewModel: viewModel, authService: authService)
            }
        }
    }

    private var notLoggedInView: some View {
        ContentUnavailableView {
            Label("Mercado", systemImage: "storefront")
        } description: {
            Text("Inicia sessão para comprar e vender cartas de Riftbound.")
        } actions: {
            NavigationLink("Ir para o Perfil") {}
        }
    }
}

// MARK: - Browse Listings

struct BrowseListingsView: View {
    @Bindable var viewModel: MarketplaceViewModel
    let authService: AuthService

    @State private var showFilters = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Pesquisar cartas...", text: $viewModel.searchText)
                    .autocorrectionDisabled()
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(.quaternary, in: .rect(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Active filters chip
            if viewModel.selectedCondition != nil || viewModel.maxPrice != nil || viewModel.selectedSet != nil || viewModel.selectedLocation != nil || viewModel.nearMeEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let set = viewModel.selectedSet {
                            activeFilterChip(text: set) { viewModel.selectedSet = nil }
                        }
                        if viewModel.nearMeEnabled {
                            activeFilterChip(text: "≤ \(Int(viewModel.nearMeRadiusKm)) km") { viewModel.nearMeEnabled = false }
                        }
                        if let loc = viewModel.selectedLocation {
                            activeFilterChip(text: loc) { viewModel.selectedLocation = nil }
                        }
                        if let cond = viewModel.selectedCondition {
                            activeFilterChip(text: cond.rawValue) { viewModel.selectedCondition = nil }
                        }
                        if let max = viewModel.maxPrice {
                            activeFilterChip(text: "≤ \(String(format: "%.0f", max))€") { viewModel.maxPrice = nil }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView("A carregar anúncios...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Erro",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if viewModel.filteredListings.isEmpty {
                ContentUnavailableView(
                    "Sem anúncios",
                    systemImage: "storefront",
                    description: Text("Ainda não há cartas à venda. Sê o primeiro a publicar!")
                )
            } else {
                List(viewModel.filteredListings) { listing in
                    NavigationLink(value: listing) {
                        ListingRowView(listing: listing)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.loadListings()
                }
            }
        }
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listing: listing, authService: authService, viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: (viewModel.selectedCondition != nil || viewModel.maxPrice != nil || viewModel.selectedSet != nil || viewModel.selectedLocation != nil || viewModel.nearMeEnabled)
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            MarketplaceFilterView(
                viewModel: viewModel,
                availableSets: viewModel.availableSets
            )
            .presentationDetents([.large])
        }
    }

    private func activeFilterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text).font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15), in: .capsule)
        .foregroundStyle(Color.accentColor)
    }
}

// MARK: - Listing Row

struct ListingRowView: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(url: listing.cardImageUrl, width: 48, height: 67)
                .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.cardName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ConditionBadge(condition: listing.condition)
                    Text(listing.cardSet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Text(listing.sellerName)
                    if !listing.location.isEmpty {
                        Text("· \(listing.location)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(listing.formattedPrice)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if listing.quantity > 1 {
                    Text("×\(listing.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let condition: CardCondition

    private var color: Color {
        switch condition {
        case .nearMint: .green
        case .lightlyPlayed: .yellow
        case .moderatelyPlayed: .orange
        case .heavilyPlayed: .red
        case .damaged: .gray
        }
    }

    var body: some View {
        Text(condition.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: .capsule)
    }
}

// MARK: - Marketplace Filter View

struct MarketplaceFilterView: View {
    @Bindable var viewModel: MarketplaceViewModel
    let availableSets: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var priceText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Set") {
                    if availableSets.isEmpty {
                        Text("Sem sets disponíveis").foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(availableSets, id: \.self) { set in
                                FilterChip(
                                    title: set,
                                    isSelected: viewModel.selectedSet == set
                                ) {
                                    viewModel.selectedSet = viewModel.selectedSet == set ? nil : set
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }

                Section("Localização") {
                    Toggle("Perto de mim", isOn: $viewModel.nearMeEnabled)
                        .onChange(of: viewModel.nearMeEnabled) {
                            if viewModel.nearMeEnabled {
                                viewModel.locationService.requestLocation()
                            }
                        }
                    if viewModel.nearMeEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Slider(value: $viewModel.nearMeRadiusKm, in: 5...150, step: 5)
                            Text("Raio: \(Int(viewModel.nearMeRadiusKm)) km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Condição") {
                    FlowLayout(spacing: 8) {
                        ForEach(CardCondition.allCases) { condition in
                            FilterChip(
                                title: condition.displayName,
                                isSelected: viewModel.selectedCondition == condition
                            ) {
                                viewModel.selectedCondition = viewModel.selectedCondition == condition ? nil : condition
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Preço máximo (€)") {
                    TextField("ex: 5.00", text: $priceText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") {
                        viewModel.selectedCondition = nil
                        viewModel.maxPrice = nil
                        viewModel.selectedSet = nil
                        viewModel.selectedLocation = nil
                        viewModel.nearMeEnabled = false
                        priceText = ""
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aplicar") {
                        viewModel.maxPrice = Double(priceText.replacingOccurrences(of: ",", with: "."))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let max = viewModel.maxPrice {
                    priceText = String(format: "%.2f", max)
                }
            }
        }
    }
}
