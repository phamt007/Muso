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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelTitle': channelTitle,
    'thumbnailUrl': thumbnailUrl,
  };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Unknown Title',
    channelTitle: json['channelTitle'] ?? 'Unknown Artist',
    thumbnailUrl: json['thumbnailUrl'] ?? '',
  );
}