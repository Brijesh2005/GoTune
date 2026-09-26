/// Encapsulates streaming information and resolution logic for a track.
class TrackStreamInfo {
  final String? directStreamUrl;
  final List<String> mirrors;
  final bool isStreamable;

  const TrackStreamInfo({
    this.directStreamUrl,
    this.mirrors = const [],
    this.isStreamable = true,
  });

  factory TrackStreamInfo.fromJson(Map<String, dynamic>? streamJson, {bool isStreamable = true}) {
    if (streamJson == null) {
      return TrackStreamInfo(isStreamable: isStreamable);
    }

    final url = streamJson['url'] as String?;
    final mirrorsList = (streamJson['mirrors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return TrackStreamInfo(
      directStreamUrl: url,
      mirrors: mirrorsList,
      isStreamable: isStreamable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': directStreamUrl,
      'mirrors': mirrors,
      'is_streamable': isStreamable,
    };
  }

  /// Resolves the best available streaming URL.
  /// Prioritizes official signed direct stream URL if available,
  /// otherwise constructs standard stream endpoint with app_name.
  String getEffectiveStreamUrl({
    required String trackId,
    required String baseUrl,
    required String appName,
    String? apiKey,
  }) {
    if (directStreamUrl != null && directStreamUrl!.isNotEmpty) {
      return directStreamUrl!;
    }

    final uri = Uri.parse('$baseUrl/tracks/$trackId/stream').replace(
      queryParameters: {
        'app_name': appName,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
      },
    );
    return uri.toString();
  }
}
