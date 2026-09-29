import 'track_model.dart';
import 'dart:convert';

class Playlist {
  final String name;
  final List<Track> tracks;

  Playlist({required this.name, required this.tracks});

  // Convert Playlist object to a Map for JSON storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tracks': tracks.map((track) => {
        'id': track.id,
        'title': track.title,
        'channelTitle': track.channelTitle,
        'thumbnailUrl': track.thumbnailUrl,
      }).toList(),
    };
  }
}