import 'track_model.dart';

class Playlist {
  final String name;
  final List<Track> tracks;

  Playlist({
    required this.name,
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    name: json['name'] ?? 'Unnamed Playlist',
    tracks: json['tracks'] != null 
        ? (json['tracks'] as List).map((item) => Track.fromJson(item as Map<String, dynamic>)).toList()
        : [],
  );
}