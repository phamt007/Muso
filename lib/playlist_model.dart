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

  // Create Playlist object back from a Map
  factory Playlist.fromMap(Map<String, dynamic> map) {
    var rawTracks = map['tracks'] as List? ?? [];
    
    List<Track> trackList = rawTracks.map((t) {
      return Track.fromMap(Map<String, dynamic>.from(t as Map));
    }).toList();

    return Playlist(
      name: map['name']?.toString() ?? 'Unnamed Playlist', 
      tracks: trackList
    );
  }


}