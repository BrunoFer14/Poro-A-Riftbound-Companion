import SwiftUI

struct CardImageView: View {
    let url: String
    let width: CGFloat
    let height: CGFloat

    @State private var uiImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
            } else if failed {
                placeholder(icon: "photo")
            } else {
                placeholder(icon: nil)
                    .overlay(ProgressView().scaleEffect(0.7))
            }
        }
        .frame(width: width, height: height)
        .task(id: url) {
            await loadImage()
        }
    }

    private func placeholder(icon: String?) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.15))
            .overlay {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private func loadImage() async {
        if let cached = ImageCache.shared.get(url) {
            uiImage = cached
            return
        }

        guard let imageURL = URL(string: url) else {
            failed = true
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard !Task.isCancelled else { return }

            // Decode image off the main thread
            let image = try await Task.detached {
                guard let img = UIImage(data: data) else {
                    throw ImageLoadError.decodingFailed
                }
                // Force decode on background thread to avoid UI hitch
                _ = img.cgImage?.dataProvider?.data
                return img
            }.value

            ImageCache.shared.set(image, for: url)
            uiImage = image
        } catch is CancellationError {
            // Task was cancelled, don't mark as failed
        } catch {
            if !Task.isCancelled {
                failed = true
            }
        }
    }
}

private enum ImageLoadError: Error {
    case decodingFailed
}

private final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 200
    }

    func get(_ url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func set(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
}
