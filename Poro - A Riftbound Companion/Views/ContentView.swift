import SwiftUI

struct ContentView: View {
    @State private var collectionStore = CollectionStore()
    @State private var deckStore = DeckStore()
    @State private var cardCache = CardCache()

    var body: some View {
        TabView {
            Tab("Cartas", systemImage: "rectangle.stack.fill") {
                CardListView(collectionStore: collectionStore, cardCache: cardCache)
            }
            Tab("Coleção", systemImage: "heart.rectangle.fill") {
                CollectionView(collectionStore: collectionStore)
            }
            Tab("Decks", systemImage: "square.3.layers.3d") {
                DeckListView(collectionStore: collectionStore, deckStore: deckStore)
            }
            Tab("Scanner", systemImage: "camera.viewfinder") {
                CardScannerView(collectionStore: collectionStore, cardCache: cardCache)
            }
        }
    }
}
