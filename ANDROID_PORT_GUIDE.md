# Poro – A Riftbound Companion (Android Port)

This is a guide to port the iOS app to Android natively using Kotlin + Jetpack Compose.
Copy this entire file content into the `CLAUDE.md` at the root of your Android project.

---

## Project Overview
Companion app for the Riftbound card game. Features:
- Browse all cards with search, filters, and pagination
- Manage a personal card collection (add/remove cards, track quantities)
- Build decks (max 40 cards, max 3 copies per card, 1 legend card)
- Import/export deck codes (community standard format)
- Live camera scanner to recognize cards via OCR
- User authentication (email/password via Firebase Auth)
- Cloud sync of collection and decks (Firebase Firestore)
- Portuguese UI labels throughout

## Tech Stack (Android)
- **Language**: Kotlin
- **UI**: Jetpack Compose + Material 3
- **Architecture**: MVVM with ViewModels + StateFlow/MutableState
- **Networking**: Retrofit + Kotlinx Serialization (or Gson)
- **Image loading**: Coil
- **Camera/OCR**: CameraX + ML Kit Text Recognition
- **Auth**: Firebase Auth (email/password)
- **Database**: Firebase Firestore (cloud) + DataStore/SharedPreferences (local)
- **Async**: Kotlin Coroutines + Flow
- **Navigation**: Compose Navigation

## API
- Base URL: `https://api.riftcodex.com`
- No authentication required
- All responses are JSON

### Endpoints

| Method | Path | Query Params | Response |
|--------|------|-------------|----------|
| GET | `/cards` | `page`, `size` | `PaginatedResponse<Card>` |
| GET | `/cards/search` | `query`, `page`, `size` | `PaginatedResponse<Card>` |
| GET | `/cards/{id}` | — | `Card` |
| GET | `/sets` | `page`, `size` | `PaginatedResponse<CardSetDetail>` |
| GET | `/sets/{id}` | — | `CardSetDetail` |

### Paginated Response Shape
```json
{
  "items": [...],
  "total": 500,
  "page": 1,
  "size": 50,
  "pages": 10
}
```

## Data Models

### Card
```kotlin
data class Card(
    val id: String,
    val name: String,
    val riftboundId: String,
    val tcgplayerId: String?,
    val publicCode: String,
    val collectorNumber: Int,
    val attributes: CardAttributes,
    val classification: CardClassification,
    val text: CardText,
    val set: CardSetRef,
    val media: CardMedia,
    val tags: List<String>,
    val orientation: String,
    val metadata: CardMetadata
)

data class CardAttributes(
    val energy: Int?,
    val might: Int?,
    val power: Int?
)

data class CardClassification(
    val type: String,
    val supertype: String?,
    val rarity: String,
    val domain: List<String>
)

data class CardText(
    val rich: String,
    val plain: String
)

data class CardSetRef(
    val setId: String,
    val label: String
)

data class CardMedia(
    val imageUrl: String,
    val artist: String,
    val accessibilityText: String
)

data class CardMetadata(
    val cleanName: String,
    val alternateArt: Boolean,
    val overnumbered: Boolean,
    val signature: Boolean
)
```

### CardSetDetail
```kotlin
data class CardSetDetail(
    val id: String,
    val name: String,
    val setId: String,
    val label: String,
    val cardCount: Int,
    val tcgplayerId: String?,
    val cardmarketId: String?,
    val publishDate: String,
    val updateDate: String
)
```

### PaginatedResponse
```kotlin
data class PaginatedResponse<T>(
    val items: List<T>,
    val total: Int,
    val page: Int,
    val size: Int,
    val pages: Int
)
```

### Collection
```kotlin
data class CollectionEntry(
    val card: Card,
    val quantity: Int
) {
    val id: String get() = card.id
}
```

### Deck
```kotlin
data class DeckEntry(
    val card: Card,
    val quantity: Int
) {
    val id: String get() = card.id
}

data class Deck(
    val id: UUID,
    val name: String,
    val legend: Card,        // The legend/champion card
    val entries: List<DeckEntry>,
    val createdAt: Date
) {
    val totalCards: Int get() = entries.sumOf { it.quantity }
    val isComplete: Boolean get() = totalCards == 40
    val domains: List<String> get() = legend.classification.domain
}
```

**Deck rules**: Max 40 cards total, max 3 copies of any single card.

## Firestore Structure
```
users/{uid}/
  collection/{cardId}  →  { cardId: String, quantity: Int, addedAt: Timestamp }
  decks/{deckId}       →  { id: String, name: String, legendCardId: String,
                             entries: [{ cardId: String, quantity: Int }],
                             createdAt: Timestamp }
```

- Only card IDs stored in Firestore (not full Card objects)
- On download, card IDs are resolved to full Card objects using the in-memory CardCache
- Document IDs: `card.id` for collection, `deck.id.toString()` for decks

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Architecture Overview

### Layers
```
UI (Compose Screens)
  ↕
ViewModels (StateFlow, business logic)
  ↕
Repositories/Stores (local persistence + Firestore write-through)
  ↕
Services (API, Auth, Firestore, OCR)
```

### Key Components to Implement

1. **ApiClient** — Retrofit interface for RiftCodex API
2. **CardCache** — In-memory cache that loads all cards via paginated API calls (page size 100)
3. **CollectionStore** — Local persistence (SharedPreferences/DataStore) + Firestore write-through
4. **DeckStore** — Same pattern as CollectionStore
5. **AuthService** — Firebase Auth wrapper (email/password sign up, sign in, sign out, reset password)
6. **FirestoreService** — CRUD for collection and decks in Firestore
7. **SyncService** — Merge logic for local + cloud data on login
8. **DeckCodec** — Encode/decode deck codes (see format below)
9. **CardRecognitionService** — ML Kit text recognition + fuzzy matching

### Sync Strategy
- **On login**: Merge local + cloud data. Collection: take `max(localQty, cloudQty)` per card. Decks: local wins on matching ID, cloud-only decks get added.
- **On changes**: Write to local AND Firestore (fire-and-forget coroutine)
- **On app launch (logged in)**: Perform sync
- **On logout**: Stop Firestore write-through, keep local data
- **Offline**: Firestore SDK has built-in offline persistence

## Deck Code Format (Community Standard)
Compatible with: https://github.com/Piltover-Archive/RiftboundDeckCodes

- Base32 encoded binary
- Version 3, Format 1
- Set IDs: OGN→0, OGS→1, ARC→2, SFD→3
- Variant suffixes: ""→0, "a"→1, "s"→2, "b"→3
- Card code format: `{SET}-{3-digit-number}{variant}` (e.g. "OGN-007a")
- Binary structure: Header → main deck groups (varint encoded) → sideboard → chosen champion
- Max copies: 12 (main deck), 3 (sideboard)

## Filter System
```kotlin
data class CardFilter(
    val selectedDomains: Set<String> = emptySet(),
    val selectedEnergyCosts: Set<Int> = emptySet(),
    val selectedSets: Set<String> = emptySet()
) {
    fun matches(card: Card): Boolean {
        // Domain filter: card must have at least one selected domain
        // Energy cost filter: card.attributes.energy must be in selected costs
        // Set filter: card.set.label must be in selected sets
        // Empty filter = no restriction (matches all)
    }
}
```

## Screens (5 tabs in bottom navigation)

1. **Cartas** (Cards) — Browse all cards in a grid, search bar, filters (domain, energy cost, set), infinite scroll pagination
2. **Coleção** (Collection) — Grid of owned cards with quantity badge, sort options (Nome, Rune Cost, Domínio, Raridade), tap to see detail
3. **Decks** — List of user decks, create/edit/delete decks, import/export deck codes
4. **Scanner** — Live camera with OCR card recognition, add/remove recognized cards to collection
5. **Perfil** (Profile) — Login/register form, sync status, sign out

## UI Labels (Portuguese)
- Cartas, Coleção, Decks, Scanner, Perfil
- Iniciar sessão, Criar conta, Terminar sessão
- Email, Palavra-passe, Confirmar palavra-passe
- Sincronização, Sincronizar agora, A sincronizar...
- Adicionar, Remover, Editar, Cancelar, Guardar
- Esqueci a palavra-passe, Já tenho conta, Criar nova conta

## Firebase Setup
- Same Firebase project as iOS (already created)
- Add Android app in Firebase Console with the Android package name
- Download `google-services.json` → place in `app/` folder
- Add Firebase SDK dependencies (BOM) in build.gradle
- Enable Email/Password in Firebase Console > Authentication > Sign-in methods
- Firestore already configured with security rules above
