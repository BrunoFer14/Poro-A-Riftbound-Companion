import SwiftUI

// Read-only star display
struct StarRatingView: View {
    let rating: Double
    let maxRating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: starImage(for: star))
                    .font(.system(size: size))
                    .foregroundStyle(star <= Int(rating.rounded()) ? Color.yellow : Color.secondary.opacity(0.3))
            }
        }
    }

    private func starImage(for star: Int) -> String {
        let rounded = rating.rounded()
        if Double(star) <= rounded { return "star.fill" }
        if Double(star) - rating < 1 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// Interactive star picker
struct StarPickerView: View {
    @Binding var rating: Int
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.4))
                    .onTapGesture { rating = star }
            }
        }
    }
}
