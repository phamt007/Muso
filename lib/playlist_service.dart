import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'playlist_model.dart';

class PlaylistService {
  static const String _storageKey = 'user_playlists';

  Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Map playlists to JSON structure
      List<String> jsonList = playlists
          .map((playlist) => json.encode(playlist.toMap()))
          .toList();
          
      // Capture the boolean result of the save attempt
      bool success = await prefs.setStringList(_storageKey, jsonList);
      
      // Force an exception if iOS returned false
      if (!success) {
        throw Exception("SharedPreferences rejected the save request.");
      }
    } catch (e) {
      // Pass the error up to trigger the global red screen
      rethrow; 
    }
  }

  // Load all playlists from device storage
  Future<List<Playlist>> loadPlaylists() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? jsonList = prefs.getStringList(_storageKey);

    if (jsonList == null) return [];

    return jsonList
        .map((jsonStr) => Playlist.fromMap(json.decode(jsonStr)))
        .toList();
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
  // Safely grab the tracks list, defaulting to an empty list if null
    var rawTracks = map['tracks'] as List? ?? [];
    
    // Explicitly cast both the Map and the List output to satisfy AOT strictness
    List<Track> trackList = rawTracks.map((t) {
      return Track.fromMap(Map<String, dynamic>.from(t as Map));
    }).toList();

    return Playlist(
      name: map['name']?.toString() ?? 'Unnamed Playlist', 
      tracks: trackList
    );
  }
}