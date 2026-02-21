import Vision
import CoreMedia

struct CardMatch: Identifiable, Sendable {
    let id = UUID()
    let card: Card
    let confidence: Double
}

enum CardRecognitionService {

    /// Extract text from a camera sample buffer using Vision OCR.
    nonisolated static func recognizeText(from sampleBuffer: CMSampleBuffer) -> [String] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    /// Match recognized text segments against a list of cards.
    nonisolated static func matchCards(texts: [String], against cards: [Card]) -> [CardMatch] {
        guard !texts.isEmpty, !cards.isEmpty else { return [] }

        let normalizedTexts = texts.map { normalize($0) }
        var bestMatches: [String: CardMatch] = [:]

        for card in cards {
            let cardName = normalize(card.name)
            guard cardName.count >= 3 else { continue }

            var bestScore = 0.0

            // Check each OCR text segment
            for text in normalizedTexts {
                // Exact containment
                if text.contains(cardName) || cardName.contains(text) {
                    let ratio = Double(min(text.count, cardName.count)) / Double(max(text.count, cardName.count))
                    bestScore = max(bestScore, 0.7 + ratio * 0.3)
                    continue
                }

                // Levenshtein similarity
                let distance = levenshteinDistance(text, cardName)
                let maxLen = max(text.count, cardName.count)
                let similarity = 1.0 - Double(distance) / Double(maxLen)
                bestScore = max(bestScore, similarity)
            }

            // Also try combining adjacent text segments (card names can span 2 lines)
            if normalizedTexts.count >= 2 {
                for i in 0..<(normalizedTexts.count - 1) {
                    let combined = normalizedTexts[i] + " " + normalizedTexts[i + 1]
                    if combined.contains(cardName) || cardName.contains(combined) {
                        let ratio = Double(min(combined.count, cardName.count)) / Double(max(combined.count, cardName.count))
                        bestScore = max(bestScore, 0.7 + ratio * 0.3)
                    } else {
                        let distance = levenshteinDistance(combined, cardName)
                        let maxLen = max(combined.count, cardName.count)
                        let similarity = 1.0 - Double(distance) / Double(maxLen)
                        bestScore = max(bestScore, similarity)
                    }
                }
            }

            if bestScore >= 0.80 {
                let existing = bestMatches[card.id]
                if existing == nil || existing!.confidence < bestScore {
                    bestMatches[card.id] = CardMatch(card: card, confidence: bestScore)
                }
            }
        }

        return bestMatches.values
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Private

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j - 1] + 1,   // insertion
                    prev[j - 1] + cost // substitution
                )
            }
            swap(&prev, &curr)
        }

        return prev[n]
    }
}
