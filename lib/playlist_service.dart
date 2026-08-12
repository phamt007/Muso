import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'playlist_model.dart';

class PlaylistService {
  static const String _storageKey = 'user_playlists';

  // Save all playlists to device storage
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Map playlists to JSON structure
    List<String> jsonList = playlists
        .map((playlist) => json.encode(playlist.toMap()))
        .toList();
        
    await prefs.setStringList(_storageKey, jsonList);
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