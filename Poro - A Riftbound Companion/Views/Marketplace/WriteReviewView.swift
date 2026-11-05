import SwiftUI
import FirebaseAuth

struct WriteReviewView: View {
    let listing: Listing
    let authService: AuthService
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating = 5
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Avaliação") {
                    VStack(spacing: 12) {
                        StarPickerView(rating: $rating)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        Text(ratingLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Comentário (opcional)") {
                    TextField("Partilha a tua experiência com este vendedor...", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Avaliar \(listing.sellerName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting)
                    .overlay {
                        if isSubmitting { ProgressView().scaleEffect(0.8) }
                    }
                }
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: "Muito mau"
        case 2: "Mau"
        case 3: "Razoável"
        case 4: "Bom"
        default: "Excelente"
        }
    }

    private func submit() async {
        guard let uid = authService.currentUser?.uid,
              let name = authService.displayName ?? authService.email
        else { return }

        isSubmitting = true
        let review = Review(
            id: "\(listing.id)_\(uid)",
            listingId: listing.id,
            sellerId: listing.sellerId,
            reviewerId: uid,
            reviewerName: name,
            rating: rating,
            comment: comment,
            createdAt: Date()
        )
        do {
            try await ReviewService.submitReview(review)
            onSubmitted()
            dismiss()
        } catch {
            errorMessage = "Erro ao publicar: \(error.localizedDescription)"
            isSubmitting = false
        }
    }
}
