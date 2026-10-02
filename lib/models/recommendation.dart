import 'package:flutter/material.dart';
import 'track.dart';

/// Represents a locally generated personalized mix (My Mix, Recent Mix, Favorites Mix, Discovery Mix, Artist Mix).
class PersonalizedMix {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradientColors;
  final IconData icon;
  final List<Track> tracks;

  const PersonalizedMix({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradientColors,
    required this.icon,
    this.tracks = const [],
  });

  String get artworkUrl => tracks.isNotEmpty ? tracks.first.thumbnailArtworkUrl : '';

  PersonalizedMix copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    List<Color>? gradientColors,
    IconData? icon,
    List<Track>? tracks,
  }) {
    return PersonalizedMix(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      gradientColors: gradientColors ?? this.gradientColors,
      icon: icon ?? this.icon,
      tracks: tracks ?? this.tracks,
    );
  }
}
