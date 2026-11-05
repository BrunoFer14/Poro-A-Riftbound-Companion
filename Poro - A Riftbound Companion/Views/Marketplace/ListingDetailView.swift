import SwiftUI
import FirebaseAuth

struct ListingDetailView: View {
    let listing: Listing
    let authService: AuthService
    let viewModel: MarketplaceViewModel

    @State private var isContactingLoading = false
    @State private var navigateToConversation: Conversation? = nil
    @State private var errorMessage: String?
    @State private var showMarkSoldAlert = false
    @State private var showDeleteAlert = false
    @State private var showWriteReview = false
    @State private var reviews: [Review] = []
    @State private var hasAlreadyReviewed = false

    @Environment(\.dismiss) private var dismiss

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    private var isMyListing: Bool {
        authService.currentUser?.uid == listing.sellerId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Card image
                CardImageView(url: listing.cardImageUrl, width: 200, height: 280)
                    .shadow(radius: 8, y: 4)
                    .padding(.vertical, 24)

                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.cardName)
                                .font(.title2.bold())
                            Text(listing.cardSet)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(listing.formattedPrice)
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)
                    }

                    // Details
                    HStack(spacing: 12) {
                        ConditionBadge(condition: listing.condition)
                        Text(listing.condition.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if listing.quantity > 1 {
                            Label("\(listing.quantity) disponíveis", systemImage: "square.stack")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Seller info
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.sellerName)
                                .font(.headline)
                            if !listing.location.isEmpty {
                                Label(listing.location, systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !reviews.isEmpty {
                                HStack(spacing: 4) {
                                    StarRatingView(rating: averageRating, maxRating: 5)
                                    Text(String(format: "%.1f", averageRating))
                                        .font(.caption.bold())
                                    Text("(\(reviews.count))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }

                    // Description
                    if !listing.description.isEmpty {
                        Divider()
                        Text("Descrição")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text(listing.description)
                            .font(.body)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    // Action button
                    if isMyListing {
                        myListingActions
                    } else if listing.status == .active {
                        contactSellerButton
                        if !hasAlreadyReviewed {
                            reviewButton
                        }
                    } else {
                        Label(
                            listing.status == .sold ? "Vendida" : "Cancelada",
                            systemImage: listing.status == .sold ? "checkmark.seal.fill" : "xmark.circle"
                        )
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 12))
                    }

                    // Posted date
                    Text("Publicado \(listing.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(listing.cardName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let r = ReviewService.fetchReviews(for: listing.sellerId)
            async let h = ReviewService.hasReviewed(listingId: listing.id, reviewerId: authService.currentUser?.uid ?? "")
            reviews = (try? await r) ?? []
            hasAlreadyReviewed = await h
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(listing: listing, authService: authService) {
                Task {
                    reviews = (try? await ReviewService.fetchReviews(for: listing.sellerId)) ?? []
                    hasAlreadyReviewed = true
                }
            }
        }
        .navigationDestination(item: $navigateToConversation) { conv in
            ConversationView(
                conversation: conv,
                authService: authService,
                onConversationUpdated: {}
            )
        }
        .alert("Eliminar anúncio?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task {
                    try? await viewModel.deleteListing(listing: listing)
                    dismiss()
                }
            }
        } message: {
            Text("O anúncio será eliminado permanentemente.")
        }
        .alert("Marcar como vendida?", isPresented: $showMarkSoldAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Marcar como vendida", role: .destructive) {
                Task { try? await viewModel.markAsSold(listing: listing) }
            }
        } message: {
            Text("O anúncio ficará inativo e não aparecerá no mercado.")
        }
    }

    private var reviewButton: some View {
        Button {
            showWriteReview = true
        } label: {
            Label("Avaliar vendedor", systemImage: "star")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.yellow.opacity(0.12), in: .rect(cornerRadius: 12))
                .foregroundStyle(Color.yellow)
        }
        .buttonStyle(.plain)
    }

    private var contactSellerButton: some View {
        Button {
            Task { await contactSeller() }
        } label: {
            HStack {
                Spacer()
                if isContactingLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Contactar vendedor", systemImage: "message.fill")
                        .font(.headline)
                }
                Spacer()
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isContactingLoading)
    }

    private var myListingActions: some View {
        VStack(spacing: 12) {
            if listing.status == .active {
                Button {
                    showMarkSoldAlert = true
                } label: {
                    Label("Marcar como vendida", systemImage: "checkmark.seal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    Task { try? await viewModel.cancelListing(listing: listing) }
                } label: {
                    Label("Cancelar anúncio", systemImage: "xmark.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Eliminar anúncio", systemImage: "trash")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func contactSeller() async {
        guard let uid = authService.currentUser?.uid,
              let name = authService.displayName ?? authService.email
        else { return }
        isContactingLoading = true
        errorMessage = nil
        do {
            let conv = try await viewModel.getOrCreateConversation(
                listing: listing,
                buyerId: uid,
                buyerName: name
            )
            navigateToConversation = conv
        } catch {
            errorMessage = "Não foi possível iniciar conversa: \(error.localizedDescription)"
        }
        isContactingLoading = false
    }
}
