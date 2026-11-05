import SwiftUI

struct CardListingsSheet: View {
    let cardName: String
    let authService: AuthService?

    @State private var listings: [Listing] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var navigateToConversation: Conversation? = nil
    @State private var marketplaceVM = MarketplaceViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("A pesquisar anúncios...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Erro",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if listings.isEmpty {
                    ContentUnavailableView(
                        "Sem anúncios",
                        systemImage: "tag.slash",
                        description: Text("Nenhum vendedor tem \"\(cardName)\" à venda de momento.")
                    )
                } else {
                    List(listings) { listing in
                        NavigationLink(value: listing) {
                            ListingRowView(listing: listing)
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: Listing.self) { listing in
                        if let auth = authService {
                            ListingDetailView(listing: listing, authService: auth, viewModel: marketplaceVM)
                        }
                    }
                }
            }
            .navigationTitle("Comprar \(cardName)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadListings()
        }
    }

    private func loadListings() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await MarketplaceService.searchListings(query: cardName)
            listings = all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
