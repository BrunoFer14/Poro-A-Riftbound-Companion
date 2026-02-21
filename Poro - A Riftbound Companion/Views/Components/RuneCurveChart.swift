import SwiftUI

struct RuneCurveChart: View {
    let curve: [(Int, Int)]

    private var maxCount: Int {
        curve.map(\.1).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(curve, id: \.0) { energy, count in
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.yellow.opacity(0.6))
                        .frame(height: max(4, CGFloat(count) / CGFloat(maxCount) * 80))

                    Image(systemName: "\(energy).circle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}
