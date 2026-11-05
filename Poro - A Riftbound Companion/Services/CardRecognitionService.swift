import Vision
import CoreMedia

struct CardMatch: Identifiable, Sendable {
    let id = UUID()
    let card: Card
    let confidence: Double
}

struct CardCodeExtraction: Sendable {
    let setId: String
    let collectorNumber: Int
    let suffix: String?
    let hasTotal: Bool
}

enum CardRecognitionService {

    nonisolated static func recognizeText(from sampleBuffer: CMSampleBuffer) -> [String] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])

        return request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
    }

    // MARK: - Code Extraction

    nonisolated static func extractCodes(from texts: [String], knownSetIds: Set<String>) -> [CardCodeExtraction] {
        guard !texts.isEmpty else { return [] }

        var results: [CardCodeExtraction] = []
        let allTexts = texts + [texts.joined(separator: " ")]

        for text in allTexts {
            results.append(contentsOf: extract(from: text, setIds: knownSetIds))
        }

        // Deduplicate, keep best
        var best: [String: CardCodeExtraction] = [:]
        for e in results {
            let key = "\(e.setId)-\(e.collectorNumber)"
            if best[key] == nil || (!best[key]!.hasTotal && e.hasTotal) {
                best[key] = e
            }
        }
        return Array(best.values)
    }

    nonisolated static func findCard(collectorNumber: Int, suffix: String?, in cards: [Card]) -> Card? {
        let candidates = cards.filter { $0.collectorNumber == collectorNumber }
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }

        if suffix == "a", let c = candidates.first(where: { $0.metadata.alternateArt }) { return c }
        if suffix == "*", let c = candidates.first(where: { $0.metadata.signature }) { return c }

        return candidates.first(where: { !$0.metadata.alternateArt && !$0.metadata.signature }) ?? candidates[0]
    }

    // MARK: - Private

    nonisolated private static func extract(from text: String, setIds: Set<String>) -> [CardCodeExtraction] {
        let upper = text.uppercased()
        var results: [CardCodeExtraction] = []

        for setId in setIds {
            var start = upper.startIndex

            while let range = upper.range(of: setId, range: start..<upper.endIndex) {
                defer { start = range.upperBound }

                // Don't match inside a longer word (but allow P before for promo)
                if range.lowerBound > upper.startIndex {
                    let before = upper[upper.index(before: range.lowerBound)]
                    if before.isLetter && before != "P" { continue }
                }

                let rest = String(upper[range.upperBound...])

                // Skip separators
                var i = rest.startIndex
                while i < rest.endIndex && "-– ".contains(rest[i]) {
                    i = rest.index(after: i)
                }
                guard i < rest.endIndex else { continue }
                let after = String(rest[i...])

                // Extract digits
                let rawLen = after.prefix(while: { $0.isNumber || $0 == "O" || $0 == "o" || $0 == "I" || $0 == "l" }).count
                guard rawLen > 0 else { continue }
                let raw = String(after.prefix(rawLen))

                // Fix OCR digits
                let fixed = fixOcrDigits(raw)
                guard let num = Int(fixed), num > 0 else { continue }

                // Suffix: a (alt art), * (signature)
                let afterNum = after.dropFirst(rawLen)
                var suffix: String?
                if let c = afterNum.first {
                    if c == "a" || c == "A" { suffix = "a" }
                    else if c == "*" { suffix = "*" }
                }

                // Check /NNN for confidence
                let compact = String(afterNum).replacingOccurrences(of: " ", with: "")
                let hasTotal = compact.contains("/") && compact.split(separator: "/").last?.first?.isNumber == true

                results.append(CardCodeExtraction(setId: setId, collectorNumber: num, suffix: suffix, hasTotal: hasTotal))
            }
        }
        return results
    }

    nonisolated private static func fixOcrDigits(_ text: String) -> String {
        var result = ""
        for char in text {
            switch char {
            case "O", "o": result.append("0")
            case "I", "l": result.append("1")
            default: result.append(char)
            }
        }
        return result
    }
}
