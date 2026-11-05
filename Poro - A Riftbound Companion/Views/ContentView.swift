import SwiftUI
import FirebaseAuth

struct ContentView: View {
    let authService: AuthService

    @State private var collectionStore = CollectionStore()
    @State private var deckStore = DeckStore()
    @State private var cardCache = CardCache()
    @State private var syncService: SyncService?
    @State private var friendsService = FriendsService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Cartas", systemImage: "rectangle.stack.fill") {
                CardListView(collectionStore: collectionStore, cardCache: cardCache, authService: authService)
            }
            Tab("Coleção", systemImage: "heart.rectangle.fill") {
                CollectionView(authService: authService, collectionStore: collectionStore, cardCache: cardCache)
            }
            Tab("Decks", systemImage: "square.3.layers.3d") {
                DeckListView(collectionStore: collectionStore, deckStore: deckStore, cardCache: cardCache)
            }
            Tab("Mercado", systemImage: "storefront") {
                MarketplaceView(authService: authService, collectionStore: collectionStore, cardCache: cardCache)
            }
            Tab("Scanner", systemImage: "camera.viewfinder") {
                CardScannerView(collectionStore: collectionStore, cardCache: cardCache, authService: authService)
            }
            Tab("Contador", systemImage: "number.circle.fill") {
                CounterView(cardCache: cardCache)
            }
            Tab("Perfil", systemImage: "person.crop.circle") {
                if let syncService {
                    ProfileView(authService: authService, syncService: syncService, friendsService: friendsService, cardCache: cardCache)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            let sync = SyncService(
                authService: authService,
                collectionStore: collectionStore,
                deckStore: deckStore,
                cardCache: cardCache
            )
            syncService = sync

            // Wait briefly for Firebase auth state to restore
            if !authService.isLoggedIn {
                try? await Task.sleep(for: .milliseconds(500))
            }

            if authService.isLoggedIn {
                await sync.performSync()
                if let uid = authService.currentUser?.uid {
                    friendsService.start(uid: uid)
                }
            }
        }
        .onChange(of: authService.isLoggedIn) {
            if authService.isLoggedIn {
                Task {
                    await syncService?.performSync()
                    await NotificationService.requestPermissionAndRegister()
                    if let uid = authService.currentUser?.uid {
                        await NotificationService.saveToken(for: uid)
                        friendsService.start(uid: uid)
                    }
                }
            } else {
                if let uid = authService.currentUser?.uid {
                    Task { await NotificationService.deleteToken(for: uid) }
                }
                syncService?.disconnect()
                friendsService.stop()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, authService.isLoggedIn {
                Task {
                    await syncService?.performSync()
                }
            }
        }
    }
}
