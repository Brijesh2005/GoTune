# GoTune Architecture

GoTune is a native Flutter / Android, **audio-only**, single-user music platform.

Its discovery, aggregation, fallback, content-detail, caching and
persistent-player architecture are **derived from the architectural concepts of
the [Youtube-clone](https://github.com/hafilrazz/Youtube-clone) reference
project** (React + TanStack Start), translated to audio.

The UI is original GoTune Flutter/GoTune branding. Only the *architecture* is
borrowed — never the React/TanStack UI, and never any provider playback
restriction circumvention.

---

## 1. Architecture mapping (reference → GoTune)

| Youtube-clone component | Purpose | GoTune equivalent | Status |
|---|---|---|---|
| `youtube.functions.ts` → `memCache` / `cacheGet` / `cacheSet` | One bounded TTL cache shared by every source | `services/music_cache_service.dart` | Migrated |
| `raceFetch(bases, path, timeoutMs)` — `Promise.any` over mirrors w/ `AbortController` | Concurrent instance race inside a single backend | `services/provider_execution.dart` → `ProviderInvoker` (timeout + bounded retry + health) | Migrated |
| Sequential multi-backend fallback in `getTrending` / `searchYouTube` / `getYouTubeVideo` (`try → catch → warn → next`) | Provider isolation, never throws | `services/music_catalog_aggregator.dart` — concurrent fan-out, per-provider isolation | Migrated (concurrent merge is strictly stronger) |
| `pipedToVideo` / `invToVideo` / `ytVideoToVideo` — normalization into **one** `Video` model | Unified content model | `models/music_content.dart` → `Track`, `Artist`, `Album`, `Playlist`, `MusicGenre`, `MusicMood` | Migrated |
| `createServerFn` + `inputValidator` — one typed API surface | Single typed facade over all sources | `services/music_discovery_service.dart` | Migrated |
| `getYouTubeVideo → { video, related }` in **one** call | Content detail = metadata + related together | `MusicDiscoveryService.getSongDetail()` → `SongDetail` | Migrated |
| `getVideosByIds` — `Promise.allSettled` + synthetic fallback per id | Batch, per-item isolation | `MusicDiscoveryService.getTracksByIds()` | Migrated |
| `getSubscriptionsFeed` — bucket by channel, round-robin interleave | Diversity filtering | `services/music_algorithm_service.dart` → `rankCandidates()` | Migrated |
| `getRecommendedFromLikes` — seeds → related + keyword + channel fan-out | Recommendations built **on top of** discovery | `MusicDiscoveryService.getRecommendations()` + `rankCandidates()` | Migrated |
| `VideoPlayerProvider` (tiny context holding only *what is playing*) | Global now-playing identity | `providers/audio_player_provider.dart` (single app-level state) | Migrated |
| `GlobalVideoPlayer` mounted **once** in `__root.tsx` **outside** `<Outlet/>`, modes `hidden` / `mini` / `inline`, never destroyed on navigation | Persistent global player | `widgets/global_audio_player.dart` → `GlobalAudioPlayer`, mounted once in `app.dart` via `MaterialApp.builder`, **above the `Navigator`** | Migrated |
| `VideoSlot` + `setSlot` — the route registers a container and the global player positions over it | Content page hosts the player | Routes never host the player; `GlobalAudioPlayer` docks itself from `AppNavigatorObserver` route depth, and `NowPlayingScreen.show()` raises a visibility flag | Migrated |
| `console.warn` per source failure | Observability | `services/provider_execution.dart` → `MusicDiagnostics` / `ProviderHealth` (a `ChangeNotifier`), surfaced in Settings → Catalog Provider Health | Migrated |
| Mirror-pool selection surfaced to the user (Invidious/Piped instance picker) | Source control | Search screen source filter (`MusicProvider.setSearchProvider` → `providerFilter` on every fan-out) | Migrated |
| Invalidating `memCache` from the UI | Cache control | Settings → Clear Catalog Cache → `MusicCatalogAggregator.invalidateCatalogCaches()` | Migrated |
| `setResponseHeader("cache-control", …)` | Freshness semantics | `MusicCacheService` TTLs + stale-while-error serving | Migrated |
| `stripHtml` / `formatSeconds` | Shared normalizers | `utils/html_unescape.dart`, `utils/duration_formatter.dart` | Migrated |
| React + Radix UI component library | UI | Flutter widgets — **not** copied by design | N/A |
| InnerTube / Piped / Invidious mirror lists | Backend instance pools | Invidious / Piped pools inside `youtube_api_service.dart` | Migrated |
| YouTube Data API v3 (official) | Authenticated final fallback | Optional `YOUTUBE_API_KEY` in `YouTubeApiService` | Migrated |
| — | — | `services/audio_source_resolver.dart` (audio analogue of "find a playable rendition") | New |

### Patterns intentionally **not** copied

* The React component tree, router, and UI kit.
* Download / third-party downloader link surfaces (`watch.$id.tsx` has a
  "Download" menu pointing at SaveFrom / 9xbuddy / Loader.to). GoTune has **no**
  downloader functionality.
* Any stream extraction, signature/token bypass, ad circumvention or DRM
  circumvention.

---

## 2. Target layer graph

```
┌────────────────────────────────────┐
│            GoTune UI               │  screens/ + widgets/
│  Home · Search · Song · Artist     │
│  Album · Playlist · Library        │
│  GlobalAudioPlayer (persistent)    │
└──────────────────┬─────────────────┘
                   ↓  MusicProvider / AudioPlayerProvider / LibraryProvider
┌────────────────────────────────────┐
│        Music Content Layer         │
│  HomeFeed · SearchDiscoveryResult  │
│  SongDetail · Artist · Album       │
│  Playlist · RadioQueue             │
└──────────────────┬─────────────────┘
                   ↓
┌────────────────────────────────────┐
│       MusicDiscoveryService        │  the ONLY door to the catalog
│  search · getHomeFeed · getTrending│
│  getPopular · getNewReleases       │
│  getGenres · getMoods              │
│  getRecommendations · getRelated   │
│  getSongDetail · getArtist         │
│  getAlbum · getPlaylist            │
│  getTracksByIds · getRadioCandidates│
└──────────────────┬─────────────────┘
                   ↓
┌────────────────────────────────────┐
│     MusicCatalogAggregator         │  concurrent fan-out, merge,
│  ProviderInvoker (timeout/retry)   │  dedupe, source consolidation,
│  MusicCacheService (bounded TTL)   │  stale-while-error
│  MusicDiagnostics (per-provider)   │
└──────────────────┬─────────────────┘
                   ↓
┌────────────────────────────────────┐
│      MusicCatalogProvider          │  abstract adapter interface
│  YouTubeCatalogProvider            │  YouTube search & discovery
└──────────────────┬─────────────────┘
                   ↓
┌────────────────────────────────────┐
│     Unified Content Model          │  MusicContent
│  Track · Artist · Album · Playlist │  (Track with YouTube video ID)
│  MusicGenre · MusicMood            │
└──────────────────┬─────────────────┘
                   ↓
┌────────────────────────────────────┐
│   UnifiedPlaybackController        │  Single source of truth
│  YouTubeIframeBackend              │  Official YouTube IFrame Player
│  webview_flutter (embedded player) │
└────────────────────────────────────┘
```

**The catalog does not know the player. The player does not perform discovery.**

Recommendation ranking is a *separate* stage:

```
Discovery candidates → normalize → user history → rankCandidates()
                    → diversity filter → final feed / queue
```

Provider discovery **finds** candidates; `MusicAlgorithmService` **ranks**
them. It never fetches.

---

## 3. Provider failure architecture

Every provider call is wrapped by `ProviderInvoker`:

* per-call **timeout** (`ProviderExecutionPolicy`)
* bounded **retry** with backoff
* **error isolation** — a throw never escapes an adapter
* **logging** — routed through `MusicDiagnostics`
* **health counters** — surfaced in Settings → Catalog Provider Health

Two call shapes are used deliberately:

* `invokeList` / `invoke` for **fan-out** — every provider is asked, one call
  contributes nothing rather than aborting the merge. A partial result from
  every catalog beats a full result from one.
* `invokeFirstSuccessful` for **single-item lookups** — ordered fallback, so a
  detail page returns one artist/album rather than a merge of near-duplicates.

Terminal fallbacks:

* All providers fail → `MusicCacheService` serves the **stale** entry
  (stale-while-error). Expired entries are deliberately *not* dropped by
  `get()`; they are purged during capacity enforcement instead.
* No cache and no network → the local provider still answers.
* No provider returns anything → the UI receives a friendly message, never an
  exception, HTTP status or JSON parse error.

These guarantees are pinned by `test/catalog_resilience_test.dart`
(concurrency, isolation, hard timeout, retry recovery, stale serve, batch
isolation, diagnostics accounting).

---

## 4. Playback architecture

### 4.1 Two real backends behind one contract

`UnifiedPlaybackController` (a `ChangeNotifier` registered once in `app.dart`)
owns queue order, shuffle/repeat, radio and track selection. It routes each
track to one of two engines through the shared `PlaybackBackend` interface, and
the UI only ever observes `UnifiedPlaybackState`:

| Track | Backend | Engine |
|---|---|---|
| `PlaybackType.directAudio` | `DirectAudioBackend` | `just_audio` + `audio_service` |
| `PlaybackType.local` | `DirectAudioBackend` | `just_audio` (MediaStore URI) |
| `PlaybackType.youtubeIframe` | `YouTubeIframeBackend` | official IFrame Player API |

`PlaybackType` is derived from the track itself (`Track.playbackType`), so
routing is data-driven rather than decided at each call site. `AudioPlayerProvider`
was removed; every screen now consumes `UnifiedPlaybackController`.

### 4.2 YouTube playback is the real embedded player

GoTune plays YouTube through the **official IFrame Player API** inside a single
WebView, the supported and documented integration path:

```
UI / UnifiedPlaybackController
      -> YouTubePlayerService        (only place that issues commands)
      -> YouTubePlayerChannel        (the testable seam)
      -> YouTubePlayerWidget         (WebView + JavaScript bridge)
      -> assets/youtube_player/index.html  (the only IFrame API code)
```

* The host page is the sole owner of `YT.Player`; Dart never builds player
  JavaScript, only calls the documented `window.*` functions.
* `onAutoplayBlocked` is registered in the player `events` map (with a
  prototype fallback for older API builds), so a refused autoplay becomes an
  explicit "tap to play" affordance instead of a silent pause.
* `onError` codes `2`, `5`, `100`, `101`, `150` and `153` are mapped to
  user-facing messages; the player is never left in a silent failed state.
* Unrecognised bridge payloads are dropped (`tryFromBridge`) rather than being
  reinterpreted as `ready`.
* Commands issued before the API finishes loading are queued behind a readiness
  completer with a bounded timeout, so a tap during start-up still plays.
* Navigation is restricted by exact host/domain suffix matching, so a
  look-alike host cannot satisfy the allowlist.
* The embedded viewport honours YouTube's documented sizing rules (minimum
  200x200 px, ~480x270 px recommended).

### 4.3 One global player surface

`GlobalAudioPlayer` is mounted once in `MaterialApp.builder`, above the
`Navigator`, and hosts:

* the mini player for every engine, and
* exactly one `YouTubePlayerWidget`, kept laid out and painted for the whole
  session with only its opacity changing.

Opening Now Playing does **not** create a WebView: it raises
`GlobalAudioPlayer.youtubeSurfaceRequested` and insets its own layout by the
same height, revealing the existing instance. Navigation never disposes it, so
switching tracks reuses the same `YT.Player` (load a new video rather than
recreate the iframe) and playback is never interrupted by a route change.

### 4.4 Mixed queues

Every queue mutation is mirrored into `GoTuneAudioHandler`, YouTube items
included. The handler's playlist is the shared index space; filtering YouTube
entries out would renumber later items and break index callbacks. When the
handler reaches a YouTube item it calls `onExternalPlaybackRequest` and hands
control back to the coordinator, which loads it into the IFrame player.

A deduplicated row can carry both a YouTube ID and a matched direct stream. The
default is the direct stream, but when the user taps the YouTube row itself
(`isExplicitYoutubeSelection`) routing is pinned to the IFrame backend via
`Track.toMediaItem(playbackTypeOverride:)`, so their chosen video plays instead
of a different recording.

### 4.5 Policy boundary

GoTune implements no DRM bypass, no protected-stream extraction, no
signature/token bypass, no ad circumvention and no downloader. Ad handling is
delegated entirely to the official player; GoTune neither intercepts nor
suppresses ads. A WebView-hosted iframe cannot keep playing with the app
backgrounded, so `supportsBackgroundPlayback` is `false` for that backend and
the UI is expected to state the limitation rather than work around it by
extracting audio. A track with no permitted playable source is reported as
unavailable rather than faked.

---

## 5. Verification status

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | No issues found |
| Unit/widget tests | `flutter test` | 100 passing |
| Release build | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` (57.0 MB) |

Test coverage of the migrated architecture:

* `test/catalog_resilience_test.dart` - concurrent fan-out, per-provider error
  isolation, hard timeout on a hanging provider, retry recovery, stale-cache
  serving, cache short-circuit, cross-provider dedupe/source consolidation,
  `contentKey` uniqueness, batch isolation, diagnostics accounting.
* `test/music_algorithm_test.dart` - ranking is pure and deterministic; seed,
  duplicate-title and implausible-duration filtering; artist diversity caps.
* `test/youtube_clone_architecture_test.dart` - model contracts for
  `HomeFeed`, `SearchDiscoveryResult` and unified content identity.
* `test/unified_playback_test.dart` - playback classification per track kind,
  `MediaItem` routing (including the explicit YouTube override), video-ID
  resolution, bridge event parsing, documented error codes, and rejection of
  malformed payloads.
* `test/youtube_iframe_backend_test.dart` - backend identity and foreground-only
  declaration, load/cue vs autoplay, refusal to load a track with no valid video
  ID, event-to-state translation (playing/paused/buffering/ended/error),
  autoplay-block reporting and single-round-trip recovery, transport commands,
  and service state reset between loads.

### Manual checklist (device required)

The embedded player needs a real Android WebView, so these are not covered by
unit tests:

1. Tap a pure YouTube search result - the embedded player appears in Now Playing
   and audio starts; confirm it is the tapped video, via YouTube IFrame.
2. Open Now Playing, then navigate away and back - one WebView instance is
   reused and playback is never interrupted.
3. Switch from a YouTube track to a direct/local track and back - only one engine
   is ever audible.
4. Enable airplane mode and confirm the player surfaces a readable error rather
   than sitting silent.
5. If autoplay is refused, confirm the "tap to start playback" affordance appears
   and one tap starts playback.

---

## 6. Audit results (A-T)

| # | Area | Result |
|---|---|---|
| A | Unified content identity | `contentKey` on all six content types; no duplicate-key violations in tests |
| B | Home feed | Typed shelves; genres/moods supplied by discovery, no UI-side catalog calls |
| C | Search | Aggregated fan-out, typed facets, moods rendered, category filter |
| D | Aggregator | Single fan-out path; per-provider timeout/retry/isolation |
| E | Provider contract | Required core + optional defaults; every adapter implements the surface |
| F | Cache | Namespaced TTL, capacity eviction, stale-while-error, user-clearable |
| G | Ranking | Pure; no repository/catalog access from `MusicAlgorithmService` |
| H | Radio | `getRadioCandidates` gathers, `rankCandidates` orders |
| I | Playback | One coordinator routes per track to `DirectAudioBackend` or `YouTubeIframeBackend` |
| J | DRM/policy | No extractor, signature, token, `.m3u8` or downloader code paths |
| K | Global player | Mini player and the single YouTube WebView mounted above `Navigator` |
| L | Player state | `processingState` derives from engine `PlayerState` |
| M | Navigation | Route depth tracked; full player suppresses the mini player |
| N | Error UX | Load states and friendly messages; raw exceptions never surfaced |
| O | Diagnostics | Per-provider counters observable via `MusicDiagnostics` |
| P | Settings | Provider health sheet + catalog cache clear |
| Q | Screens | No imports of catalog/discovery/algorithm services (Settings: cache/aggregator by intent) |
| R | Dead code | Swept; remaining unreferenced members are framework overrides or retained public API |
| S | Duplicate logic | Live paths consolidated onto `MusicDiscoveryService`; shadow methods removed |
| T | Build | `flutter analyze` clean, 64 tests passing, release APK 56.1 MB |

### Unrendered-but-populated data

* `HomeFeed.newReleases` feeds the recommended pool and is exposed for a future
  "New Releases" shelf; no shelf renders it yet.
* `HomeScreen` keeps a hardcoded genre list **only** as an offline first-run
  fallback when discovery facets are empty.

### Retained public API with no in-app caller

* `AudioPlayerProvider.clearError`
* `SettingsProvider.updateCustomBaseUrl`
* `BaseAudioHandler.removeQueueItem` / `skipToQueueItem` (framework overrides)
