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
}