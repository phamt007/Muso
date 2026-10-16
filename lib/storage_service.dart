import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'playlist_model.dart';

class StorageService {
  static const String _key = 'saved_playlists_v2'; 

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  Future<List<Playlist>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    
    if (jsonString == null || jsonString.isEmpty) return [];
    
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((item) => Playlist.fromJson(item as Map<String, dynamic>)).toList();
  }
}