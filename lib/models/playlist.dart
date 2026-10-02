import '../utils/duration_formatter.dart';
import 'music_content.dart';
import 'track.dart';

/// Represents a user-created personal playlist containing curated tracks.
class Playlist implements MusicContent {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Track> tracks;
  @override
  final String provider;
  @override
  final Map<String, dynamic> metadata;

  const Playlist({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.tracks = const [],
    this.provider = 'local',
    this.metadata = const {},
  });

  @override
  String get providerId => id;

  @override
  ContentType get contentType => ContentType.playlist;

  @override
  String get contentKey => '$provider:${contentType.name}:$providerId';

  @override
  String get title => name;

  @override
  String get subtitle => '$trackCount tracks';

  @override
  String get artworkUrl => coverArtworkUrl;

  @override
  bool get isPlayable => tracks.isNotEmpty;

  int get trackCount => tracks.length;

  int get totalDurationSeconds =>
      tracks.fold(0, (sum, track) => sum + track.durationSeconds);

  String get formattedTotalDuration =>
      DurationFormatter.formatSeconds(totalDurationSeconds);

  /// Artwork of the first track in playlist or empty string if empty.
  String get coverArtworkUrl {
    for (final track in tracks) {
      if (track.bestArtworkUrl.isNotEmpty) {
        return track.bestArtworkUrl;
      }
    }
    return '';
  }

  bool containsTrack(String trackId) {
    return tracks.any((t) => t.id == trackId);
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Track>? tracks,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tracks: tracks ?? List.from(this.tracks),
      provider: provider,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'] as List<dynamic>? ?? [];
    final parsedTracks = <Track>[];
    for (final item in rawTracks) {
      if (item is Map<String, dynamic>) {
        try {
          parsedTracks.add(Track.fromJson(item));
        } catch (_) {}
      }
    }

    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Playlist',
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      tracks: parsedTracks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
