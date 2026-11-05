# Poro – A Riftbound Companion (Android Port)

This document describes the complete iOS app to be ported to Android with **all features preserved exactly as they are**. The Android app must be a 1:1 functional replica.

---

## Tech Stack (Android)

- **Language:** Kotlin
- **UI:** Jetpack Compose (Material 3)
- **Architecture:** MVVM with `StateFlow` / `MutableStateFlow`
- **Networking:** Ktor + kotlinx.serialization (custom flat decoder for card schema)
- **Image Loading:** Coil (with in-memory LRU cache, limit ~200 images)
- **Camera:** CameraX
- **OCR:** ML Kit Text Recognition
- **Auth:** Firebase Authentication (email/password)
- **Cloud Storage:** Cloud Firestore
- **Local Persistence:** DataStore or Room (JSON-encoded, matching iOS UserDefaults approach)
- **Navigation:** Compose Navigation with typed routes
- **Dependency Injection:** Hilt

---

## API

- **Base URL:** `https://api.rifthunt.com`
- **Auth:** None required
- **Primary endpoints:**
  - `GET /bulk/cards` → all cards in a single request (~1.2 MB JSON) — use this to populate CardCache
  - `GET /sets` → list of all sets (wrapped in `{ data: [...] }`)
  - `GET /cards/search?q=X&page=N&size=M` → server-side text search (use for card picker search if cache not loaded yet)
  - `GET /cards/{id}` → single card by RiftHunt ID
  - `GET /bulk/prices` → daily TCGPlayer pricing for all cards

**Bulk cards response shape:**
```json
{
  "fetched": "2026-11-02T...",
  "source": "riotgames.com",
  "sets": [ { "id": "RAD", "name": "Radiance", "count": 250, "released": "2026-10-23" }, ... ],
  "cards": [ { ...card fields... }, ... ]
}
```

**Sets response shape:**
```json
{
  "object": "list",
  "has_more": false,
  "data": [ { "id": "uuid", "code": "rad", "name": "Radiance", "card_count": 250, "release_date": "2026-10-23T00:00:00.000Z" }, ... ]
}
```

---

## Models

### Card

The RiftHunt card schema is **flat** (no nested attribute/classification/text objects in the JSON). The Android model should expose the same grouped structure internally but deserialize from the flat JSON.

**JSON fields (from `/bulk/cards`):**
```
id              String   "rad-001-167"
riftboundId     String   same as id
name            String
cleanName       String   for Cardmarket URL slugs
num             Int      collector number
energy          Int?
might           Int?
power           Int?
type            String   "Unit" | "Gear" | "Spell" | "Battlefield" | "Legend"
supertype       String?
rarity          String   "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Showcase"
domains         [String] e.g. ["Fury", "Order"]
text            String   plain text with [Keyword] markers and :rb_xxx: tokens
rich            String   HTML version of text
flavour         String?
set             String   uppercase set code "RAD"
setName         String   "Radiance"
tags            [String] e.g. ["Darius", "Noxus"]
artist          String
tcgId           String?
imgUrl          String   full Riot CDN URL
img             String   relative path (not needed)
orientation     String   "portrait" | "landscape"
alt             Boolean  alternate art
sig             Boolean  signature version
over            Boolean  overnumbered
imgHash         String   (not needed)
```

**Kotlin data class:**
```kotlin
data class Card(
    val id: String,                      // "rad-001-167"
    val name: String,
    val riftboundId: String,
    val collectorNumber: Int,            // from "num"
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
    val domain: List<String>             // from "domains"
)

data class CardText(
    val rich: String,
    val plain: String,                   // from "text"
    val flavour: String?
)

data class CardSetRef(
    val setId: String,                   // from "set", uppercase e.g. "RAD"
    val label: String                    // from "setName"
)

data class CardMedia(
    val imageUrl: String,                // from "imgUrl"
    val artist: String
)

data class CardMetadata(
    val cleanName: String?,
    val alternateArt: Boolean,           // from "alt"
    val overnumbered: Boolean,           // from "over"
    val signature: Boolean               // from "sig"
)
```

### CardSetDetail

Deserialized from `/sets` response (`data` array). The `code` field is lowercase in the API — uppercase it on parse.

```kotlin
data class CardSetDetail(
    val id: String,
    val name: String,
    val setId: String,       // uppercased "code" field, e.g. "RAD"
    val cardCount: Int,      // from "card_count"
    val publishedOn: String  // from "release_date", ISO 8601 — sort descending for newest first
)
```

### CollectionEntry

```kotlin
data class CollectionEntry(
    val card: Card,
    var quantity: Int,
    var foilQuantity: Int = 0,
    var promoQuantity: Int = 0
) {
    val id: String get() = card.id
    val totalQuantity: Int get() = quantity + foilQuantity + promoQuantity
}
```

### CardFilter

```kotlin
data class CardFilter(
    val selectedDomains: Set<String> = emptySet(),
    val selectedEnergyCosts: Set<Int> = emptySet(),
    val selectedSets: Set<String> = emptySet(),
    val selectedTypes: Set<String> = emptySet(),
    val selectedRarities: Set<String> = emptySet()
) {
    val isActive: Boolean get() =
        selectedDomains.isNotEmpty() || selectedEnergyCosts.isNotEmpty() ||
        selectedSets.isNotEmpty() || selectedTypes.isNotEmpty() || selectedRarities.isNotEmpty()

    fun matches(card: Card): Boolean {
        val isBattlefield = card.classification.type == "Battlefield"
        if (selectedTypes.isNotEmpty() && card.classification.type !in selectedTypes) return false
        if (selectedRarities.isNotEmpty() && card.classification.rarity !in selectedRarities) return false
        if (selectedDomains.isNotEmpty()) {
            val domainMatch = card.classification.domain.any { it in selectedDomains }
            if (!domainMatch) return false
            if ("Colorless" in selectedDomains && isBattlefield && "Battlefield" !in selectedTypes) return false
        }
        if (selectedEnergyCosts.isNotEmpty()) {
            val energy = card.attributes.energy ?: return false
            if (energy !in selectedEnergyCosts) return false
        }
        if (selectedSets.isNotEmpty() && card.set.label !in selectedSets) return false
        return true
    }

    fun reset() = CardFilter()
}
```

### Deck

```kotlin
data class DeckEntry(val card: Card, var quantity: Int) { val id: String get() = card.id }

data class Deck(
    val id: UUID,
    var name: String,
    val legend: Card,
    var entries: MutableList<DeckEntry>,
    var battlefields: MutableList<Card>,
    var runes: MutableMap<String, Int>,   // domain → count
    val createdAt: Date
) {
    val totalCards: Int get() = entries.sumOf { it.quantity }
    val hasAllBattlefields: Boolean get() = battlefields.size == 3
    val totalRunes: Int get() = runes.values.sum()
    val hasAllRunes: Boolean get() = totalRunes == 12
    val isComplete: Boolean get() = totalCards == 40 && hasAllBattlefields && hasAllRunes
    val domains: List<String> get() = legend.classification.domain
}
```

**Deck rules:**
- Max 40 main deck cards
- Max 3 copies of any single card (also capped by owned quantity)
- Exactly 3 battlefields (no duplicates)
- Exactly 12 runes total, split across legend's domains (e.g. 12-0, 6-6, 8-4)
- Domain matching: main deck cards must share at least one domain with the legend

---

## Persistence

### CollectionStore

- **Storage key:** `poro_collection_v2` (v2 — schema changed with RiftHunt migration)
- **Format:** JSON array of `CollectionEntry` (full Card objects embedded)
- **Write-through:** When `authUid` is set, every change also syncs to Firestore
- **Methods:**
  - `quantity(cardId)`, `foilQuantity(cardId)`, `promoQuantity(cardId)`, `totalQuantity(cardId)`
  - `increment(card)` / `decrement(card)` — normal copies
  - `incrementFoil(card)` / `decrementFoil(card)` — foil copies
  - `incrementPromo(card)` / `decrementPromo(card)` — promo copies
  - `replaceAll(entries)` — bulk replace (used by sync)
  - `resetSet(setId)` — remove all entries for a set

### DeckStore

- **Storage key:** `poro_decks_v1`
- **Format:** JSON array of `Deck`
- **Write-through:** When `authUid` is set, every add/update/delete syncs to Firestore
- **Methods:** `addDeck`, `updateDeck`, `deleteDeck`, `replaceAll`

---

## Firestore Schema

```
users/{uid}/
  profile/
    displayName: String
    email: String
    createdAt: Timestamp

  collection/{cardId}
    cardId: String
    quantity: Int
    foilQuantity: Int
    promoQuantity: Int
    addedAt: Timestamp

  decks/{deckId}
    id: String (UUID)
    name: String
    legendCardId: String
    entries: [{cardId: String, quantity: Int}]
    battlefieldCardIds: [String]
    runes: {domain: Int}
    createdAt: Timestamp

friends/{targetUid}
  status: "pending" | "accepted"
  initiator: Boolean   // true if this user sent the request
  since: Timestamp

friendRequests/{requestId}
  fromUid: String
  toUid: String
  fromDisplayName: String
  status: "pending" | "accepted" | "declined"
  createdAt: Timestamp
```

### Sync Logic (SyncService)

**Collection merge:**
- Download cloud entries + load local entries
- For each card: `merged_qty = max(local_qty, cloud_qty)` (same for foil and promo)
- Resolve card IDs to full Card objects using CardCache
- Replace local store + upload merged result

**Deck merge:**
- Download cloud decks + load local decks
- Matching IDs: keep local version
- Cloud-only decks: import by resolving card IDs from CardCache
- Replace local store + upload merged result

**On logout:** Clear `authUid`, keep local data.

---

## CardCache

Single-request bulk load from `/bulk/cards`. Must handle concurrent callers (only one network load).

```kotlin
class CardCache {
    var allCards: List<Card> = emptyList()
    var isLoaded: Boolean = false
    var isLoading: Boolean = false

    fun cards(forSet label: String): List<Card>     // filter by set.label
    fun cards(forSetId id: String): List<Card>      // filter by set.setId
    fun otherVersions(of card: Card): List<Card>    // alt art, sig, same collector number
    suspend fun loadIfNeeded()                       // idempotent, concurrent-safe
}
```

**Loading:** One GET `/bulk/cards`, parse `cards` array, deduplicate by `id`, store in memory.

---

## Screens / Navigation

### Tab Bar (BottomNavigation)

| Tab | Label | Screen |
|-----|-------|--------|
| 1 | Cartas | CardListScreen |
| 2 | Coleção | CollectionScreen |
| 3 | Decks | DeckListScreen |
| 4 | Mercado | MarketplaceScreen |
| 5 | Scanner | ScannerScreen |
| 6 | Contador | CounterScreen |
| 7 | Perfil | ProfileScreen |

---

### 1. Cartas Tab

#### CardListScreen (tab root)
- Fetches sets from `GET /sets`, sorted by `publishedOn` descending
- **First row:** "Todas as Cartas" entry with subtitle "Pesquisar em todas as expansões" and search icon → AllCardsScreen
- Remaining rows: set name + card count + chevron → SetCardListScreen

#### AllCardsScreen
- Loads ALL cards from CardCache (single bulk call, shared cache)
- Identical UX to SetCardListScreen but:
  - Navigation title: "Todas as Cartas"
  - Filter sheet includes **Expansão** section (filter by set)
  - No progress count (doesn't show X de Y)
- Search is client-side (substring match on loaded cards)

#### SetCardListScreen
- Loads cards for the specific set from CardCache (`cards(forSetId: set.setId)`)
- Shows loading progress: "X de Y" while CardCache is first loading
- Features: search bar (300ms debounce), filter button, sort menu
- Sort options: Nome, Energia, Might, Power, Raridade, Nº Colecionador
- Each row: `CardRowView` with collection +/- buttons
- Tap → CardDetailScreen

#### CardFilterSheet (bottom sheet)
- Sections: **Expansão** (AllCardsScreen only), **Tipo**, **Raridade**, **Domínio**, **Custo de Energia**
- FlowLayout chip rows, "Limpar" button

#### CardDetailScreen
- Large card image (260x364)
- Card name + supertype, rarity badge
- Attribute chips: Energy (yellow), Might (red), Power (blue)
- Info rows: Tipo, Domínio, Set, Nº Colecionador, Artista
- Card text: `RichCardText` renderer
- Tags as `#tag` text
- "Outras versões (N)" row → CardVersionsScreen (grid of alt/sig cards)
- **Cardmarket link:** `https://www.cardmarket.com/en/Riftbound/Products/Singles/{cleanName}` — open in browser
- Marketplace buy/sell buttons (logged-in only)
- **Collection stepper — Normal:** large minus (red)/plus (tint), animated count, "na coleção" label
- **Collection stepper — Foil:** smaller, ✦ icon (purple), "foil" label
- **Collection stepper — Promo:** smaller, "P" label (orange), "promo" label

---

### 2. Coleção Tab

#### CollectionScreen (tab root)
- "Todas" row → all collected cards
- Per-expansion rows: set name + `"X / Y"` progress (green when complete)
- Y = non-alt-art, non-overnumbered cards in that set from CardCache

#### CollectionSetScreen
- Adaptive grid (min 100dp)
- Progress bar: `"X / Y"` owned
- Sort chips: Nome, Rune Cost, Domínio, Raridade
- **Show missing toggle** (eye icon): shows unowned cards at 35% opacity (excluding alt/overnumbered)
- Filter button, search bar
- Cells: image (100x140), quantity badge `×N`, foil badge `✦N`, name below
- Tap → CardDetailScreen

---

### 3. Decks Tab

#### DeckListScreen
- List of decks, swipe-to-delete
- Each row: legend image (52x73), deck name, legend name, domain badges, `N/40` (green if complete)
- Toolbar: import button, `+` new deck
- New → LegendPickerSheet → DeckBuilderScreen
- Import → DeckImportSheet

#### DeckBuilderScreen (full screen)
- Legend header: image, editable name, legend name, domain badges, `N/40`
- Runes section: per-domain +/- with total 12 cap
- Battlefields section: → BattlefieldPickerSheet, shows up to 3 images (70x98)
- Rune Curve chart
- Cards grid (adaptive, sorted by energy)
- `+` toolbar → DeckCardPickerSheet
- Auto-save on every change

#### DeckDetailScreen
- Read-only view, same content as builder
- Toolbar: delete (confirm dialog), copy deck code, edit
- Toast "Código copiado!" for 2 seconds

#### DeckImportSheet
- Text input for deck code → decode → preview → "Guardar Deck"

---

### 4. Mercado Tab

#### MarketplaceScreen
- Tab bar inside screen: "Explorar" | "As minhas" | "Mensagens"
- **Explorar:** paginated list of active listings; each row shows card image, name, set, condition, price, seller
  - Filter by: card name search, condition, price range
  - Tap → ListingDetailScreen
- **As minhas:** user's own active listings, with delete swipe action
- **Mensagens:** list of conversations (buyer↔seller), swipe to remove
  - Tap → ConversationScreen

#### ListingDetailScreen
- Card image, name, set, rarity
- Seller info (display name, rating stars)
- Condition, price, description
- Location (city, country)
- "Comprar / Contactar" button → opens ConversationScreen
- "Escrever review" button (if past transaction)

#### CreateListingView (sheet)
- Pick card (search from CardCache)
- Set condition, price, description, location
- Submit → Firestore

#### ConversationScreen
- Real-time message list (Firestore listener)
- Text input + send button

---

### 5. Scanner Tab

#### ScannerScreen
- Camera permission flow
- Full-screen CameraX preview + scanning indicator
- Match found (confidence ≥ 0.90): overlay slides up
  - Card image (80x112), name, set, confidence %
  - Collection stepper (normal only in scanner)
  - "OK" → dismiss, resume scanning
- OCR strategy:
  - Throttle: one frame per 0.3s
  - Match by card public code format `"SET-NNN/TOTAL"` or `"SET-NNN"`
  - OCR fixes: O→0, I/l→1, S→5, B→8
  - Confidence: exact=1.0, set+number=0.98, regex=0.95/0.92
  - Minimum threshold: 0.90
- Camera stops on tab leave, resumes on return
- CardCache must be loaded before scanning

**Android equivalents:**
- `AVCaptureSession` → CameraX `ProcessImageProxy`
- `VNRecognizeTextRequest` → ML Kit `TextRecognizer`

---

### 6. Contador Tab

#### CounterScreen — Setup phase
- Pick Player 1 legend → pick Player 2 legend (opponent excluded)
- Choose format: Best of 1 / Best of 3

#### CounterScreen — Game phase
- Split screen: Player 2 rotated 180° at top, Player 1 at bottom
- Each half (`PlayerCounterHalf`): legend art background (blurred, 40% opacity), player label, large animated score (0–8), minus/plus buttons, "Vitória!" at 8
- Center bar: back, game counter (Bo3), reset
- Win at 8 points; Bo3 = first to 2 game wins

---

### 7. Perfil Tab

#### ProfileScreen
- **Logged out:** login prompt + "Iniciar sessão" button → AuthSheet
- **Logged in:**
  - Avatar, display name, email
  - Sync status indicator
  - "Sincronizar agora" button
  - **Amigos** section (see Friends System below)
  - "Terminar sessão" (red)

#### AuthSheet
- Login / Register toggle
- Email + password fields (+ confirm password for register)
- "Esqueci a password" link → reset email
- Firebase errors mapped to Portuguese

---

## Friends System

### Overview
Users can add friends by searching email/username. Friends can see each other's collection (read-only).

### Firestore Schema

```
users/{uid}/
  profile/
    displayName: String
    email: String

  friends/{friendUid}
    status: "pending" | "accepted"
    initiator: Boolean
    displayName: String    // cached for display without extra fetch
    since: Timestamp
```

### FriendsService

```kotlin
// Search users by display name or email
suspend fun searchUsers(query: String): List<UserProfile>

// Send friend request
suspend fun sendRequest(toUid: String)

// Accept / decline incoming request
suspend fun acceptRequest(fromUid: String)
suspend fun declineRequest(fromUid: String)

// Remove friend
suspend fun removeFriend(uid: String)

// Real-time friends list
fun friendsFlow(uid: String): Flow<List<Friend>>

// Read a friend's collection (read-only)
suspend fun getFriendCollection(friendUid: String): List<CollectionEntry>
```

### Screens

#### FriendsListScreen
- List of accepted friends: avatar initial, display name, "Ver coleção" button
- Pending requests section: incoming requests with accept/decline buttons
- Search bar + "Adicionar amigo" button → UserSearchSheet

#### UserSearchSheet
- Search by display name or email
- Results list with "Adicionar" button per user
- Already-friends / pending states shown

#### FriendCollectionScreen
- Read-only view of a friend's collection
- Identical UI to CollectionScreen but no +/- buttons
- Title: "{friendName}'s Coleção"

---

## Shared Components

### CardImageView
- Async image, in-memory LRU cache (200 entries), off-main decode
- Loading: centered small spinner; Error: gray rectangle with photo icon
- Parameters: `url: String, width: Dp, height: Dp`

### RarityBadgeView
| Rarity | Color |
|--------|-------|
| Common | Gray |
| Uncommon | Green |
| Rare | Blue |
| Epic | Purple |
| Legendary | Orange |
| Showcase | Yellow |

### DomainBadge
| Domain | Color |
|--------|-------|
| Body | Orange |
| Calm | Green |
| Chaos | Purple |
| Fury | Red |
| Mind | Blue |
| Order | Yellow |
| Default | Gray |

### RichCardText
Parses card `text.plain` and renders inline icons + bold keywords.

**Symbol tokens** (`:rb_xxx:` format → colored icons/text):
- `:rb_energy_N:` → yellow numbered circle (N = 0–9)
- `:rb_rune_body:` orange, `:rb_rune_calm:` green, `:rb_rune_chaos:` purple, `:rb_rune_fury:` red, `:rb_rune_mind:` blue, `:rb_rune_order:` yellow
- `:rb_rune_rainbow:` → sparkles icon
- `:rb_rune_exhausted:` → gray bolt.slash icon
- `:rb_exhaust:` → gray arrow.counterclockwise icon
- `:rb_might:` → red shield icon

**Keyword markers:** `[Keyword]` → **bold**

### RuneCurveChart
Bar chart of energy cost distribution. Yellow bars, proportional height (max 80dp), cost labels on X-axis, count on top of each bar.

### FlowLayout
Flexbox-like wrapping chip layout. Left-to-right, wraps to next row at max width.

---

## Deck Codec (Shareable Deck Codes)

Binary format encoded as Base32 (RFC 4648, no padding).

### Format
```
Byte 0: (format=1 << 4) | version=3

Main Deck: for count 12..1 → varint(groups) → for each group: varint(cards), byte(set_id), byte(variant_id), varints(collector_numbers)
Sideboard: same structure (currently empty)
Champion: 0x01 + set_id + variant_id + varint(collector_number), or 0x00
```

### Set IDs
| Set | ID |
|-----|-----|
| OGN | 0 |
| OGS | 1 |
| ARC | 2 |
| SFD | 3 |
| UNL | 4 |
| VEN | 5 |
| RAD | 6 |
| PR  | 7 |
| OPP | 8 |
| JDG | 9 |
| RWB | 10 |
| SGN | 11 |

### Variant IDs
| Variant | ID |
|---------|----|
| Normal | 0 |
| Alternate Art | 1 |
| Signature | 2 |

### Varint Encoding (LEB128)
```
while value != 0: byte = value & 0x7F; value >>= 7; if value != 0: byte |= 0x80; emit byte
special case: value == 0 → emit 0x00
```

---

## Language

All user-facing text is in **Portuguese (pt-PT)**. Key strings:

| Key | String |
|-----|--------|
| Tab: Cards | "Cartas" |
| Tab: Collection | "Coleção" |
| Tab: Decks | "Decks" |
| Tab: Market | "Mercado" |
| Tab: Scanner | "Scanner" |
| Tab: Counter | "Contador" |
| Tab: Profile | "Perfil" |
| All cards row | "Todas as Cartas" |
| All cards subtitle | "Pesquisar em todas as expansões" |
| Search placeholder | "Pesquisar cartas..." |
| Foil label | "foil" |
| Promo label | "promo" |
| In collection | "na coleção" |
| Clear filters | "Limpar" |
| No results (filter) | "Sem resultados" |
| No results desc | "Nenhuma carta corresponde aos filtros selecionados." |
| Friends | "Amigos" |
| Add friend | "Adicionar amigo" |
| View collection | "Ver coleção" |
| Pending | "Pendente" |
| Accept | "Aceitar" |
| Decline | "Recusar" |
| Friend collection title | "{name}'s Coleção" |
| Delete confirmation | "Apagar este deck?" |
| Code copied | "Código copiado!" |
| Camera denied | "Câmara não disponível" |
| Sync now | "Sincronizar agora" |
| Login | "Iniciar sessão" |
| Register | "Criar conta" |
| Sign out | "Terminar sessão" |
| Import | "Importar" |
| Save deck | "Guardar Deck" |

---

## Key Behaviors & Edge Cases

1. **CardCache uses a single bulk request** (`/bulk/cards`) — no pagination needed
2. **Deduplication:** filter cards by unique `id` after bulk parse
3. **Collection stores full Card objects** (no re-fetch needed)
4. **CollectionEntry has three quantities:** `quantity` (normal), `foilQuantity`, `promoQuantity`
5. **Storage key is `poro_collection_v2`** — v1 data (from old RiftCodex schema) is incompatible and should be ignored
6. **CardCache concurrent loading** — Mutex/coroutine pattern; only one network call even with multiple simultaneous callers
7. **Search is client-side** — substring match on cached `allCards`; no API search calls during normal browsing
8. **Scanner uses CardCache** to look up `setId + collectorNumber` matches
9. **Counter rotation** — Player 2's half rotated 180° for face-to-face play
10. **Alt art / overnumbered exclusions:**
    - Collection progress: exclude from unique counts
    - Missing cards toggle: exclude from missing list
    - Counter legend picker: exclude from legend grid
11. **Cardmarket URL:** `https://www.cardmarket.com/en/Riftbound/Products/Singles/{metadata.cleanName}`
12. **Friends collection** is read-only — no +/- buttons, no sync
13. **Set codes in deck codec** are uppercase in the app but the API `sets[].code` is lowercase — uppercase on parse
