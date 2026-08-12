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

  // Converts YouTube API's complex JSON response into our simple Track object
  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id']['videoId'] ?? '',
      title: json['snippet']['title'] ?? 'Unknown Title',
      channelTitle: json['snippet']['channelTitle'] ?? 'Unknown Artist',
      thumbnailUrl: json['snippet']['thumbnails']['medium']['url'] ?? '',
    );
  }
}