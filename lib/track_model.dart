class Track {
  final String id;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;

  Track({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    // YouTube search endpoint nests video ID inside an object: {"id": {"videoId": "..."}}
    final idData = json['id'];
    final String videoId = idData is Map<String, dynamic> ? (idData['videoId'] ?? '') : json['id'] ?? '';

    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final highRes = thumbnails['high'] ?? thumbnails['medium'] ?? thumbnails['default'] ?? {};

    return Track(
      id: videoId,
      title: snippet['title'] ?? 'Unknown Title',
      channelTitle: snippet['channelTitle'] ?? 'Unknown Artist',
      thumbnailUrl: highRes['url'] ?? '',
    );
  }
}