import 'music_content.dart';
import 'track.dart';

/// Represents a music album in the GoTune catalog.
class Album implements MusicContent {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  @override
  final String? artworkUrl;
  final int? year;
  final int trackCount;
  @override
  final String provider;
  final List<Track> tracks;
  @override
  final Map<String, dynamic> metadata;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.artworkUrl,
    this.year,
    this.trackCount = 0,
    this.provider = 'youtube',
    this.tracks = const [],
    this.metadata = const {},
  });

  @override
  String get providerId => id;

  @override
  ContentType get contentType => ContentType.album;

  @override
  String get contentKey => '$provider:${contentType.name}:$providerId';

  @override
  String get title => name;

  @override
  String get subtitle => artist;

  @override
  bool get isPlayable => tracks.isNotEmpty;

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id']?.toString() ?? '',
      name: json['title']?.toString() ?? json['name']?.toString() ?? 'Unknown Album',
      artist: json['artist']?.toString() ?? json['primary_artists']?.toString() ?? 'Various Artists',
      artistId: json['artist_id']?.toString(),
      artworkUrl: json['image']?.toString() ?? json['artworkUrl']?.toString(),
      year: int.tryParse(json['year']?.toString() ?? ''),
      trackCount: int.tryParse(json['song_count']?.toString() ?? json['trackCount']?.toString() ?? '0') ?? 0,
      provider: json['provider']?.toString() ?? 'youtube',
    );
  }

  /// Returns a copy with the supplied fields replaced.
  Album copyWith({
    String? id,
    String? name,
    String? artist,
    String? artistId,
    String? artworkUrl,
    int? year,
    int? trackCount,
    String? provider,
    List<Track>? tracks,
    Map<String, dynamic>? metadata,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      year: year ?? this.year,
      trackCount: trackCount ?? this.trackCount,
      provider: provider ?? this.provider,
      tracks: tracks ?? this.tracks,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'artistId': artistId,
      'artworkUrl': artworkUrl,
      'year': year,
      'trackCount': trackCount,
      'provider': provider,
      'metadata': metadata,
    };
  }
}
