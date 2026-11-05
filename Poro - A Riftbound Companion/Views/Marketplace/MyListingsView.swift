import SwiftUI
import FirebaseAuth

struct MyListingsView: View {
    let viewModel: MarketplaceViewModel
    let authService: AuthService

    @State private var selectedStatus: ListingStatus? = nil

    private var filteredListings: [Listing] {
        if let status = selectedStatus {
            return viewModel.myListings.filter { $0.status == status }
        }
        return viewModel.myListings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(label: "Todos", status: nil)
                    statusChip(label: "Ativos", status: .active)
                    statusChip(label: "Vendidos", status: .sold)
                    statusChip(label: "Cancelados", status: .cancelled)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredListings.isEmpty {
                ContentUnavailableView(
                    "Sem anúncios",
                    systemImage: "tag",
                    description: Text("Ainda não publicaste nenhum anúncio.")
                )
            } else {
                List(filteredListings) { listing in
                    NavigationLink(value: listing) {
                        MyListingRowView(listing: listing)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { try? await viewModel.deleteListing(listing: listing) }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Listing.self) { listing in
                    ListingDetailView(
                        listing: listing,
                        authService: authService,
                        viewModel: viewModel
                    )
                }
            }
        }
        .task {
            if let uid = authService.currentUser?.uid {
                await viewModel.loadMyListings(sellerId: uid)
            }
        }
    }

    private func statusChip(label: String, status: ListingStatus?) -> some View {
        let isSelected = selectedStatus == status
        return Button {
            withAnimation(.snappy) { selectedStatus = status }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: .capsule)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct MyListingRowView: View {
    let listing: Listing

    private var statusColor: Color {
        switch listing.status {
        case .active: .green
        case .sold: .blue
        case .cancelled: .red
        }
    }

    private var statusLabel: String {
        switch listing.status {
        case .active: "Ativo"
        case .sold: "Vendido"
        case .cancelled: "Cancelado"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(url: listing.cardImageUrl, width: 40, height: 56)
                .clipShape(.rect(cornerRadius: 4))
                .opacity(listing.status == .active ? 1 : 0.5)

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
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(listing.formattedPrice)
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
