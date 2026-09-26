import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/duration_formatter.dart';
import '../utils/html_unescape.dart';
import 'track_stream_info.dart';

/// Represents a music track with complete metadata, artwork, and streaming info.
class Track {
  final String id;
  final String title;
  final String artist;
  final String? artistHandle;
  final bool isArtistVerified;
  final String? artworkUrl150;
  final String? artworkUrl480;
  final String? artworkUrl1000;
  final int durationSeconds;
  final String genre;
  final int playCount;
  final int favoriteCount;
  final int repostCount;
  final String provider;
  final TrackStreamInfo streamInfo;
  final DateTime? releaseDate;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.artistHandle,
    this.isArtistVerified = false,
    this.artworkUrl150,
    this.artworkUrl480,
    this.artworkUrl1000,
    this.durationSeconds = 0,
    this.genre = 'Music',
    this.playCount = 0,
    this.favoriteCount = 0,
    this.repostCount = 0,
    this.provider = 'audius',
    this.streamInfo = const TrackStreamInfo(),
    this.releaseDate,
  });

  /// Highest resolution available artwork URL with graceful fallback.
  String get bestArtworkUrl {
    if (artworkUrl480 != null && artworkUrl480!.isNotEmpty) return artworkUrl480!;
    if (artworkUrl1000 != null && artworkUrl1000!.isNotEmpty) return artworkUrl1000!;
    if (artworkUrl150 != null && artworkUrl150!.isNotEmpty) return artworkUrl150!;
    return '';
  }

  /// Thumbnail size artwork.
  String get thumbnailArtworkUrl {
    if (artworkUrl150 != null && artworkUrl150!.isNotEmpty) return artworkUrl150!;
    if (artworkUrl480 != null && artworkUrl480!.isNotEmpty) return artworkUrl480!;
    return '';
  }

  /// Formatted duration string (e.g. "3:42").
  String get formattedDuration => DurationFormatter.formatSeconds(durationSeconds);

  /// Converts this Track to an [audio_service] MediaItem for background playback.
  MediaItem toMediaItem({String? resolvedStreamUrl}) {
    final effectiveStream = resolvedStreamUrl ??
        (streamInfo.directStreamUrl != null && streamInfo.directStreamUrl!.isNotEmpty
            ? streamInfo.directStreamUrl
            : null);
    return MediaItem(
      id: id,
      album: genre.isNotEmpty
          ? genre
          : (provider == 'saavn'
              ? 'JioSaavn'
              : (provider == 'youtube' ? 'YouTube' : 'Audius')),
      title: title,
      artist: artist,
      duration: Duration(seconds: durationSeconds),
      artUri: bestArtworkUrl.isNotEmpty ? Uri.tryParse(bestArtworkUrl) : null,
      extras: {
        'provider': provider,
        'streamUrl': effectiveStream,
        'artistHandle': artistHandle,
        'isVerified': isArtistVerified,
        'mirrors': streamInfo.mirrors,
      },
    );
  }

  /// Creates a Track instance from an Audius API JSON object.
  factory Track.fromAudiusJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    final artworkJson = json['artwork'] as Map<String, dynamic>?;
    final streamJson = json['stream'] as Map<String, dynamic>?;

    DateTime? parsedDate;
    if (json['release_date'] != null) {
      parsedDate = DateTime.tryParse(json['release_date'].toString());
    } else if (json['created_at'] != null) {
      parsedDate = DateTime.tryParse(json['created_at'].toString());
    }

    return Track(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'Untitled Track',
      artist: (userJson?['name'] as String?)?.trim().isNotEmpty == true
          ? userJson!['name'].toString().trim()
          : (userJson?['handle'] as String?) ?? 'Unknown Artist',
      artistHandle: userJson?['handle']?.toString(),
      isArtistVerified: userJson?['is_verified'] == true,
      artworkUrl150: artworkJson?['150x150']?.toString(),
      artworkUrl480: artworkJson?['480x480']?.toString(),
      artworkUrl1000: artworkJson?['1000x1000']?.toString(),
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      genre: json['genre']?.toString() ?? 'Music',
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      repostCount: (json['repost_count'] as num?)?.toInt() ?? 0,
      provider: 'audius',
      streamInfo: TrackStreamInfo.fromJson(
        streamJson,
        isStreamable: json['is_streamable'] != false,
      ),
      releaseDate: parsedDate,
    );
  }

  /// Creates a Track instance from a JioSaavn song JSON object.
  factory Track.fromSaavnJson(
    Map<String, dynamic> json, {
    String? decryptedStreamUrl,
  }) {
    final moreInfo = json['more_info'] as Map<String, dynamic>?;

    // Parse artists cleanly from artistMap or subtitle
    String artistName = '';
    final primaryArtistsList = moreInfo?['artistMap']?['primary_artists'] as List<dynamic>?;
    if (primaryArtistsList != null && primaryArtistsList.isNotEmpty) {
      artistName = primaryArtistsList
          .map((a) => a is Map ? a['name']?.toString() : null)
          .where((name) => name != null && name.trim().isNotEmpty)
          .join(', ');
    }
    if (artistName.isEmpty && json['subtitle'] != null) {
      final subtitle = json['subtitle'].toString();
      final parts = subtitle.split(' - ');
      artistName = parts.first.trim();
    }
    if (artistName.isEmpty && moreInfo?['music'] != null) {
      artistName = moreInfo!['music'].toString();
    }
    if (artistName.isEmpty) {
      artistName = 'Unknown Artist';
    }

    final rawTitle = json['title']?.toString() ?? 'Untitled Track';
    final cleanTitle = HtmlUnescape.unescape(rawTitle);
    final cleanArtist = HtmlUnescape.unescape(artistName);

    // Duration in seconds
    int duration = 0;
    if (moreInfo?['duration'] != null) {
      duration = int.tryParse(moreInfo!['duration'].toString()) ?? 0;
    } else if (json['duration'] != null) {
      duration = int.tryParse(json['duration'].toString()) ?? 0;
    }

    // Artwork: 150x150, 500x500
    final baseImage = json['image']?.toString();
    final art150 = baseImage;
    final art500 = baseImage?.replaceAll('150x150.jpg', '500x500.jpg');

    // Language / Genre
    final lang = json['language']?.toString().trim();
    final album = moreInfo?['album']?.toString().trim();
    String genre = 'Bollywood';
    if (lang != null && lang.isNotEmpty) {
      genre = lang[0].toUpperCase() + lang.substring(1);
    } else if (album != null && album.isNotEmpty) {
      genre = HtmlUnescape.unescape(album);
    }

    DateTime? releaseDate;
    if (json['year'] != null) {
      final yr = int.tryParse(json['year'].toString());
      if (yr != null && yr > 1900) {
        releaseDate = DateTime(yr);
      }
    }

    return Track(
      id: json['id']?.toString() ?? '',
      title: cleanTitle.isNotEmpty ? cleanTitle : 'Untitled Track',
      artist: cleanArtist.isNotEmpty ? cleanArtist : 'Unknown Artist',
      artworkUrl150: art150,
      artworkUrl480: art500,
      artworkUrl1000: art500,
      durationSeconds: duration,
      genre: genre,
      playCount: int.tryParse(json['play_count']?.toString() ?? '0') ?? 0,
      provider: 'saavn',
      streamInfo: TrackStreamInfo(
        directStreamUrl: decryptedStreamUrl,
        isStreamable: decryptedStreamUrl != null && decryptedStreamUrl.isNotEmpty,
      ),
      releaseDate: releaseDate,
    );
  }

  /// Creates a Track instance from a YouTube video result.
  factory Track.fromYoutubeVideo(
    Video video, {
    String? resolvedStreamUrl,
  }) {
    final rawTitle = HtmlUnescape.unescape(video.title);
    final rawAuthor = HtmlUnescape.unescape(video.author);

    // Clean author by stripping ' - Topic' suffix
    final cleanAuthor = rawAuthor
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .trim();
    String artist = cleanAuthor;
    String title = rawTitle;

    // Many music tracks on YouTube follow "Artist - Title" format
    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      final possibleArtist = parts.first.trim();
      final possibleTitle = parts.sublist(1).join(' - ').trim();
      if (possibleArtist.isNotEmpty && possibleTitle.isNotEmpty) {
        artist = possibleArtist;
        title = possibleTitle;
      }
    }

    // Strip common audio/video clutter tags from title
    title = title
        .replaceAll(
          RegExp(
            r'\s*[\(\[](official\s*(music\s*)?video|official\s*audio|official\s*lyric\s*video|lyric\s*video|official|audio|video|lyrics|hd|4k|hq|visualizer)[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (title.isEmpty) title = rawTitle;
    if (artist.isEmpty) artist = 'Unknown Artist';

    final videoId = video.id.value;
    final art150 = video.thumbnails.lowResUrl;
    final art480 = video.thumbnails.mediumResUrl;
    final art1000 = video.thumbnails.highResUrl;

    return Track(
      id: 'yt_$videoId',
      title: title,
      artist: artist,
      artworkUrl150: art150,
      artworkUrl480: art480,
      artworkUrl1000: art1000,
      durationSeconds: video.duration?.inSeconds ?? 0,
      genre: 'Universal',
      provider: 'youtube',
      streamInfo: TrackStreamInfo(
        directStreamUrl: resolvedStreamUrl,
        isStreamable: true,
      ),
      releaseDate: video.uploadDate,
    );
  }

  /// Serializes to JSON for local persistence (SharedPreferences).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artistHandle': artistHandle,
      'isArtistVerified': isArtistVerified,
      'artworkUrl150': artworkUrl150,
      'artworkUrl480': artworkUrl480,
      'artworkUrl1000': artworkUrl1000,
      'durationSeconds': durationSeconds,
      'genre': genre,
      'playCount': playCount,
      'favoriteCount': favoriteCount,
      'repostCount': repostCount,
      'provider': provider,
      'streamInfo': streamInfo.toJson(),
      'releaseDate': releaseDate?.toIso8601String(),
    };
  }

  /// Deserializes from local JSON storage.
  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Track',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      artistHandle: json['artistHandle']?.toString(),
      isArtistVerified: json['isArtistVerified'] == true,
      artworkUrl150: json['artworkUrl150']?.toString(),
      artworkUrl480: json['artworkUrl480']?.toString(),
      artworkUrl1000: json['artworkUrl1000']?.toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      genre: json['genre']?.toString() ?? 'Music',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      provider: json['provider']?.toString() ?? 'audius',
      streamInfo: TrackStreamInfo.fromJson(
        json['streamInfo'] as Map<String, dynamic>?,
        isStreamable: true,
      ),
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'].toString())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
