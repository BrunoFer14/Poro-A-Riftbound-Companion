import SwiftUI

struct RichCardText: View {
    let text: String
    var font: Font = .body

    var body: some View {
        parseText(text)
            .font(font)
    }

    private func parseText(_ input: String) -> Text {
        var result = Text("")
        var remaining = input[input.startIndex...]

        // Match :rb_xxx: symbols or [Keyword] patterns
        let pattern = #":rb_[a-z0-9_]+:|\[[^\]]+\]"#

        while !remaining.isEmpty {
            guard let range = remaining.range(of: pattern, options: .regularExpression) else {
                result = result + Text(String(remaining))
                break
            }

            // Text before match
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            if !before.isEmpty {
                result = result + Text(before)
            }

            let match = String(remaining[range])

            if match.hasPrefix(":rb_") {
                let code = match.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                if let symbol = symbolInfo(for: code) {
                    result = result + Text(Image(systemName: symbol.systemName))
                        .foregroundColor(symbol.color)
                } else {
                    result = result + Text(match)
                }
            } else if match.hasPrefix("[") {
                let keyword = String(match.dropFirst().dropLast())
                result = result + Text(keyword).bold()
            }

            remaining = remaining[range.upperBound...]
        }

        return result
    }

    private func symbolInfo(for code: String) -> (systemName: String, color: Color)? {
        switch code {
        // Energy
        case "rb_energy_0": return ("0.circle.fill", .yellow)
        case "rb_energy_1": return ("1.circle.fill", .yellow)
        case "rb_energy_2": return ("2.circle.fill", .yellow)
        case "rb_energy_3": return ("3.circle.fill", .yellow)
        case "rb_energy_4": return ("4.circle.fill", .yellow)
        case "rb_energy_5": return ("5.circle.fill", .yellow)
        // Runes
        case "rb_rune_body":      return ("circle.fill", .green)
        case "rb_rune_calm":      return ("circle.fill", .cyan)
        case "rb_rune_chaos":     return ("circle.fill", .red)
        case "rb_rune_fury":      return ("circle.fill", .orange)
        case "rb_rune_mind":      return ("circle.fill", .purple)
        case "rb_rune_order":     return ("circle.fill", .blue)
        case "rb_rune_rainbow":   return ("sparkle", .primary)
        case "rb_rune_exhausted": return ("circle.dotted", .secondary)
        // Mechanics
        case "rb_exhaust": return ("arrow.triangle.2.circlepath", .secondary)
        case "rb_might":   return ("flame.fill", .red)
        default: return nil
        }
    }
}
