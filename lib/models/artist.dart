import 'music_content.dart';
import 'track.dart';

/// Represents a music artist in the GoTune catalog.
class Artist implements MusicContent {
  final String id;
  final String name;
  @override
  final String? artworkUrl;
  final int followersCount;
  final String? bio;
  @override
  final String provider;
  final bool isVerified;
  final List<Track> popularTracks;
  @override
  final Map<String, dynamic> metadata;

  const Artist({
    required this.id,
    required this.name,
    this.artworkUrl,
    this.followersCount = 0,
    this.bio,
    this.provider = 'youtube',
    this.isVerified = false,
    this.popularTracks = const [],
    this.metadata = const {},
  });

  @override
  String get providerId => id;

  @override
  ContentType get contentType => ContentType.artist;

  @override
  String get contentKey => '$provider:${contentType.name}:$providerId';

  @override
  String get title => name;

  @override
  String get subtitle {
    if (followersCount > 0) return '$followersCount followers';
    return isVerified ? 'Verified artist' : 'Artist';
  }

  @override
  bool get isPlayable => popularTracks.isNotEmpty;

  factory Artist.fromJson(Map<String, dynamic> json) {    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Unknown Artist',
      artworkUrl: json['image']?.toString() ?? json['artworkUrl']?.toString(),
      followersCount: int.tryParse(json['follower_count']?.toString() ?? '0') ?? 0,
      bio: json['bio']?.toString(),
      provider: json['provider']?.toString() ?? 'youtube',
      isVerified: json['is_verified'] == true || json['isVerified'] == true,
    );
  }

  /// Returns a copy with the supplied fields replaced.
  Artist copyWith({
    String? id,
    String? name,
    String? artworkUrl,
    int? followersCount,
    String? bio,
    String? provider,
    bool? isVerified,
    List<Track>? popularTracks,
    Map<String, dynamic>? metadata,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      followersCount: followersCount ?? this.followersCount,
      bio: bio ?? this.bio,
      provider: provider ?? this.provider,
      isVerified: isVerified ?? this.isVerified,
      popularTracks: popularTracks ?? this.popularTracks,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Returns a copy whose top tracks are replaced by [tracks].
  Artist copyWithTracks(List<Track> tracks) {
    return Artist(
      id: id,
      name: name,
      artworkUrl: artworkUrl,
      followersCount: followersCount,
      bio: bio,
      provider: provider,
      isVerified: isVerified,
      popularTracks: tracks,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artworkUrl': artworkUrl,
      'followersCount': followersCount,
      'bio': bio,
      'provider': provider,
      'isVerified': isVerified,
      'metadata': metadata,
    };
  }
}
