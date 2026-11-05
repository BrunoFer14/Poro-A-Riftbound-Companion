import SwiftUI

struct PlayerCounterHalf: View {
    let legend: Card
    @Binding var points: Int
    let maxPoints: Int = 8
    let disabled: Bool

    init(legend: Card, points: Binding<Int>, disabled: Bool = false) {
        self.legend = legend
        self._points = points
        self.disabled = disabled
    }

    var body: some View {
        ZStack {
            // Background: legend card art
            AsyncImage(url: URL(string: legend.media.imageUrl)) { phase in
                if let image = phase.image {
                    GeometryReader { geo in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height * 1.3)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                    }
                } else {
                    Color.black
                }
            }

            // Dark overlay
            Color.black.opacity(isWin ? 0.3 : 0.5)

            if isWin {
                Color.yellow.opacity(0.15)
            }

            // Content
            VStack(spacing: 12) {
                Text(legend.name)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                if isWin {
                    Text("Vitória!")
                        .font(.title2.bold())
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 8)
                }

                Text("\(points)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: points)

                HStack(spacing: 40) {
                    Button {
                        guard points > 0 else { return }
                        points -= 1
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(points > 0 ? 0.9 : 0.3))
                    }
                    .disabled(points <= 0 || disabled)

                    Button {
                        guard points < maxPoints else { return }
                        points += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(points < maxPoints ? 0.9 : 0.3))
                    }
                    .disabled(points >= maxPoints || disabled)
                }

                Spacer()
            }
            .padding()
        }
    }

    private var isWin: Bool { points >= maxPoints }
}
