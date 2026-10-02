import '../utils/duration_formatter.dart';
import '../utils/html_unescape.dart';
import 'music_content.dart';
import 'playback_type.dart';

/// Unified Track model representing a YouTube music track.
/// Contains metadata, video identifier for the official YouTube IFrame Player,
/// artwork URLs, and duration.
class Track implements MusicContent {
  final String id;
  @override
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final Duration? _duration;
  final String source; // 'youtube'

  // Supplementary YouTube metadata fields
  final String? youtubeVideoId;
  final String? artworkUrl150;
  final String? artworkUrl480;
  final String? artworkUrl1000;
  final int durationSeconds;
  final String genre;
  final bool explicit;
  @override
  final Map<String, dynamic> metadata;
  final String? artistId;
  final String? albumId;
  final int? playCount;
  final DateTime? releaseDate;
  final bool isArtistVerified;
  final PlaybackType sourceType;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    Duration? duration,
    String? source,
    String? provider,
    this.youtubeVideoId,
    String? providerTrackId,
    String? sourceId,
    String? albumName,
    PlaybackType? sourceType,
    this.artworkUrl150,
    this.artworkUrl480,
    this.artworkUrl1000,
    this.durationSeconds = 0,
    this.genre = 'Music',
    this.explicit = false,
    this.metadata = const {},
    this.artistId,
    this.albumId,
    this.playCount,
    this.releaseDate,
    this.isArtistVerified = false,
  })  : _duration = duration,
        source = provider ?? source ?? 'youtube',
        sourceType = sourceType ?? PlaybackType.youtubeIframe;

  Duration? get duration =>
      _duration ?? (durationSeconds > 0 ? Duration(seconds: durationSeconds) : null);

  // Backward-compatible aliases
  @override
  String get provider => source;
  String? get albumName => album;
  String? get providerTrackId => resolvedYoutubeVideoId;
  String? get sourceId => resolvedYoutubeVideoId;
  bool get isLocal => false;

  /// High-resolution artwork URL (~480-500px).
  String get bestArtworkUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl!;
    if (artworkUrl480 != null && artworkUrl480!.isNotEmpty) return artworkUrl480!;
    if (artworkUrl150 != null && artworkUrl150!.isNotEmpty) return artworkUrl150!;
    if (artworkUrl1000 != null && artworkUrl1000!.isNotEmpty) return artworkUrl1000!;
    final vid = resolvedYoutubeVideoId;
    if (vid != null && vid.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
    }
    return '';
  }

  /// Compact thumbnail size artwork (~150px) for lists.
  String get thumbnailArtworkUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl!;
    if (artworkUrl150 != null && artworkUrl150!.isNotEmpty) return artworkUrl150!;
    if (artworkUrl480 != null && artworkUrl480!.isNotEmpty) return artworkUrl480!;
    final vid = resolvedYoutubeVideoId;
    if (vid != null && vid.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$vid/default.jpg';
    }
    return '';
  }

  @override
  String get artworkUrl => bestArtworkUrl;

  /// Formatted duration string (e.g. "3:42").
  String get formattedDuration => DurationFormatter.formatSeconds(durationSeconds);

  // --- YouTube IFrame playback ---

  /// Resolves the clean 11-character YouTube video ID to hand to `YT.Player`.
  String? get resolvedYoutubeVideoId {
    final explicitId = youtubeVideoId;
    if (explicitId != null && explicitId.isNotEmpty) {
      return explicitId;
    }

    if (id.startsWith('yt_')) {
      final stripped = id.substring(3);
      if (stripped.isNotEmpty) return stripped;
    }

    if (_looksLikeYoutubeVideoId(id)) return id;

    return null;
  }

  static bool _looksLikeYoutubeVideoId(String value) {
    if (value.length != 11) return false;
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value);
  }

  PlaybackType get playbackType => PlaybackType.youtubeIframe;

  bool get isYouTubeIframe => true;

  @override
  String get providerId => resolvedYoutubeVideoId ?? id;

  @override
  ContentType get contentType => ContentType.song;

  @override
  String get contentKey => '$provider:song:$providerId';

  @override
  String get subtitle => artist;

  @override
  bool get isPlayable => resolvedYoutubeVideoId != null || id.isNotEmpty;

  // --- Normalization & Deduplication ---

  static String normalizeTitle(String raw) {
    if (raw.trim().isEmpty) return '';
    var s = HtmlUnescape.unescape(raw).toLowerCase();
    s = s.replaceAll(
      RegExp(
        r'[\(\[](official\s*(music\s*)?video|official\s*audio|audio|lyrics|lyric\s*video|hq|hd|remastered[^\)\]]*|visualizer|album\s*version|live|acoustic[^\)\]]*)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'[\(\[]\s*(feat\.|ft\.|featuring)\s+[^)\]]+[\)\]]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+-\s+.*$'), '');
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String normalizeArtist(String raw) {
    if (raw.trim().isEmpty) return '';
    var s = HtmlUnescape.unescape(raw).toLowerCase();
    s = s.replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*vevo$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*(feat\.|ft\.|featuring|,|&)\s+.*$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^the\s+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  bool isSimilarTo(Track other) {
    final titleA = normalizeTitle(title);
    final titleB = normalizeTitle(other.title);
    if (titleA.isEmpty || titleB.isEmpty) return false;

    if (titleA == titleB) return true;

    final artistA = normalizeArtist(artist);
    final artistB = normalizeArtist(other.artist);
    final sameArtist = artistA.isNotEmpty && artistB.isNotEmpty &&
        (artistA == artistB || artistA.contains(artistB) || artistB.contains(artistA));

    if (sameArtist && (titleA.contains(titleB) || titleB.contains(titleA))) {
      return true;
    }

    if (durationSeconds > 0 && other.durationSeconds > 0) {
      final diff = (durationSeconds - other.durationSeconds).abs();
      if (diff <= 3 && sameArtist) {
        return true;
      }
    }

    return false;
  }

  /// Compact canonical fingerprint for cross-catalog deduplication.
  String get normalizedFingerprint {
    final t = normalizeTitle(title);
    final a = normalizeArtist(artist);
    if (t.isEmpty && a.isEmpty) return id;
    return '$t::$a';
  }

  /// Deduplicates tracks preserving first-occurrence order.
  static List<Track> deduplicate(List<Track> tracks) {
    final seen = <String>{};
    final result = <Track>[];
    for (final track in tracks) {
      final fp = track.normalizedFingerprint;
      if (seen.add(fp)) {
        result.add(track);
      }
    }
    return result;
  }

  // --- Factory Constructors for YouTube Data ---

  factory Track.fromYouTubeJson(Map<String, dynamic> json) {
    final videoId = json['videoId']?.toString() ??
        json['id']?.toString() ??
        '';

    final rawTitle = json['title']?.toString() ?? 'Untitled Track';
    final cleanTitle = HtmlUnescape.unescape(rawTitle);

    String artist = json['author']?.toString() ?? json['artist']?.toString() ?? 'YouTube Music';
    String finalTitle = cleanTitle;

    if (cleanTitle.contains(' - ') && (artist == 'YouTube Music' || artist.isEmpty)) {
      final parts = cleanTitle.split(' - ');
      artist = parts[0].trim();
      finalTitle = parts.sublist(1).join(' - ').trim();
    }

    final durationSec = (json['lengthSeconds'] as num?)?.toInt() ??
        (json['duration'] as num?)?.toInt() ??
        0;

    String? art;
    if (json['videoThumbnails'] is List && (json['videoThumbnails'] as List).isNotEmpty) {
      final thumbs = json['videoThumbnails'] as List;
      art = thumbs.last['url']?.toString();
    } else if (videoId.isNotEmpty) {
      art = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }

    return Track(
      id: videoId.isNotEmpty ? videoId : 'yt_$videoId',
      youtubeVideoId: videoId.isNotEmpty ? videoId : null,
      title: finalTitle.isNotEmpty ? finalTitle : 'Untitled Track',
      artist: artist.isNotEmpty ? artist : 'YouTube Artist',
      thumbnailUrl: art,
      artworkUrl150: art,
      artworkUrl480: art,
      artworkUrl1000: art,
      durationSeconds: durationSec,
      duration: Duration(seconds: durationSec),
      genre: json['genre']?.toString() ?? 'Music',
      source: 'youtube',
      metadata: Map<String, dynamic>.from(json),
    );
  }

  factory Track.fromMetadata({
    required String id,
    required String title,
    required String artist,
    String? artworkUrl,
    int durationSeconds = 0,
    String genre = 'Music',
    String? albumName,
    String? albumId,
    String? artistId,
    String? youtubeVideoId,
    String source = 'youtube',
    String? provider,
    String? streamUrl,
    String? sourceType,
    DateTime? releaseDate,
    bool explicit = false,
    Map<String, dynamic> metadata = const {},
  }) {
    final cleanId = id.startsWith('yt_') ? id.substring(3) : id;
    final vid = youtubeVideoId ?? (_looksLikeYoutubeVideoId(cleanId) ? cleanId : null);

    return Track(
      id: vid ?? id,
      youtubeVideoId: vid,
      title: title,
      artist: artist,
      album: albumName,
      thumbnailUrl: artworkUrl,
      artworkUrl150: artworkUrl,
      artworkUrl480: artworkUrl,
      artworkUrl1000: artworkUrl,
      durationSeconds: durationSeconds,
      duration: Duration(seconds: durationSeconds),
      genre: genre,
      source: 'youtube',
      explicit: explicit,
      metadata: metadata,
      artistId: artistId,
      albumId: albumId,
      releaseDate: releaseDate,
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
    Duration? duration,
    String? source,
    String? youtubeVideoId,
    String? artworkUrl150,
    String? artworkUrl480,
    String? artworkUrl1000,
    int? durationSeconds,
    String? genre,
    bool? explicit,
    Map<String, dynamic>? metadata,
    String? artistId,
    String? albumId,
    String? albumName,
    String? provider,
    String? providerTrackId,
    int? playCount,
    DateTime? releaseDate,
    bool? isArtistVerified,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? albumName ?? this.album,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      source: source ?? provider ?? this.source,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      artworkUrl150: artworkUrl150 ?? this.artworkUrl150,
      artworkUrl480: artworkUrl480 ?? this.artworkUrl480,
      artworkUrl1000: artworkUrl1000 ?? this.artworkUrl1000,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      genre: genre ?? this.genre,
      explicit: explicit ?? this.explicit,
      metadata: metadata ?? this.metadata,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      playCount: playCount ?? this.playCount,
      releaseDate: releaseDate ?? this.releaseDate,
      isArtistVerified: isArtistVerified ?? this.isArtistVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'thumbnailUrl': thumbnailUrl ?? bestArtworkUrl,
      'durationSeconds': durationSeconds,
      'source': 'youtube',
      'youtubeVideoId': resolvedYoutubeVideoId,
      'genre': genre,
      'explicit': explicit,
      'artistId': artistId,
      'albumId': albumId,
      'playCount': playCount,
      'releaseDate': releaseDate,
      'isArtistVerified': isArtistVerified,
      'metadata': metadata,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final vid = json['youtubeVideoId']?.toString() ??
        (rawId.startsWith('yt_') ? rawId.substring(3) : rawId);
    final art = json['thumbnailUrl']?.toString() ??
        json['artworkUrl480']?.toString() ??
        json['artworkUrl']?.toString() ??
        json['artworkUrl150']?.toString();
    final durationSec = (json['durationSeconds'] as num?)?.toInt() ??
        (json['duration'] as num?)?.toInt() ??
        0;

    return Track(
      id: rawId,
      title: json['title']?.toString() ?? 'Untitled Track',
      artist: json['artist']?.toString() ?? 'YouTube Artist',
      album: json['album']?.toString() ?? json['albumName']?.toString(),
      thumbnailUrl: art,
      artworkUrl150: art,
      artworkUrl480: art,
      artworkUrl1000: art,
      durationSeconds: durationSec,
      duration: Duration(seconds: durationSec),
      source: 'youtube',
      youtubeVideoId: vid.isNotEmpty ? vid : null,
      genre: json['genre']?.toString() ?? 'Music',
      explicit: json['explicit'] == true,
      artistId: json['artistId']?.toString(),
      albumId: json['albumId']?.toString(),
      playCount: (json['playCount'] as num?)?.toInt(),
      releaseDate: json['releaseDate'] != null ? DateTime.tryParse(json['releaseDate'].toString()) : null,
      isArtistVerified: json['isArtistVerified'] == true,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
