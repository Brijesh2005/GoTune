/// The kind of item a piece of music content represents.
///
/// Every provider normalizes its native payloads into one of these types so
/// the UI never needs to know which catalog a result came from.
enum ContentType {
  song,
  artist,
  album,
  playlist,
  genre,
  mood,
  channel,
}

/// Base abstraction for every addressable piece of music content.
///
/// This mirrors the reference architecture's single `Video` model, which every
/// backend (Piped, Invidious, YouTube Data API, InnerTube) normalizes into.
/// GoTune has more content shapes than a video site, so instead of one concrete
/// class every shape — [Track], [Artist], [Album], [Playlist], [MusicGenre] and
/// [MusicMood] — implements this interface and carries a consistent
/// `provider` / `providerId` / `contentType` identity.
abstract class MusicContent {
  /// Stable identifier of the catalog that owns this item (`youtube`, ...).
  String get provider;

  /// Identifier of this item *within* [provider].
  String get providerId;

  /// Which content shape this is.
  ContentType get contentType;

  /// Primary human-readable label.
  String get title;

  /// Secondary label (artist, owner, description, ...).
  String get subtitle;

  /// Best available artwork URL, or `null` when the catalog has none.
  String? get artworkUrl;

  /// Provider-specific extra data retained verbatim for round-tripping.
  Map<String, dynamic> get metadata;

  /// Globally unique key across catalogs: `<provider>:<contentType>:<providerId>`.
  String get contentKey => '$provider:${contentType.name}:$providerId';

  /// Whether this item can be handed to the player without further resolution.
  bool get isPlayable;
}

/// A discovery facet used to group or filter content (e.g. "Electronic").
class MusicGenre implements MusicContent {
  @override
  final String provider;
  @override
  final String providerId;
  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String artworkUrl;
  @override
  final Map<String, dynamic> metadata;

  MusicGenre({
    required this.title,
    this.provider = 'builtin',
    String? providerId,
    this.subtitle = 'Genre',
    this.artworkUrl = '',
    this.metadata = const {},
  }) : providerId = providerId != null && providerId.isNotEmpty
            ? providerId
            : _slug(title);

  @override
  ContentType get contentType => ContentType.genre;

  @override
  String get contentKey => '$provider:${contentType.name}:$providerId';

  @override
  bool get isPlayable => false;

  @override
  String toString() => 'MusicGenre($title)';
}

/// A listener-facing mood facet (e.g. "Chill", "Workout").
class MusicMood implements MusicContent {
  @override
  final String provider;
  @override
  final String providerId;
  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String artworkUrl;
  @override
  final Map<String, dynamic> metadata;

  MusicMood({
    required this.title,
    this.provider = 'builtin',
    String? providerId,
    this.subtitle = 'Mood',
    this.artworkUrl = '',
    this.metadata = const {},
  }) : providerId = providerId != null && providerId.isNotEmpty
            ? providerId
            : _slug(title);

  @override
  ContentType get contentType => ContentType.mood;

  @override
  String get contentKey => '$provider:${contentType.name}:$providerId';

  @override
  bool get isPlayable => false;

  @override
  String toString() => 'MusicMood($title)';
}

/// Lowercases a label and replaces separators with dashes so a facet always has
/// a stable, URL-safe [MusicContent.providerId].
String _slug(String value) {
  final lower = value.toLowerCase().trim();
  if (lower.isEmpty) return '';
  return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
