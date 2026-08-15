import 'dart:convert';
import 'package:http/http.dart' as http;
import 'track_model.dart';

class YouTubeService {
  // PASTE YOUR GOOGLE CLOUD YOUTUBE API KEY HERE
  final String _apiKey = 'AIzaSyASUKO5DWO1h1nKW6WMYYq6ZaCVtDumbsw'; 
  final bool debugMode = false; 

    // In-memory cache map to store previous search queries
    final Map<String, List<Track>> _searchCache = {};

    Future<List<Track>> searchMusic(String query) async {
      final cleanQuery = query.trim().toLowerCase();

      // === STRATEGY 3: MOCK DATA FOR DESIGNING ===
      if (debugMode) {
        print("🚧 DEBUG MODE ACTIVE: Returning zero-quota fake test tracks.");
        await Future.delayed(const Duration(milliseconds: 400)); // Mimics network lag
        return [
          Track(
            id: 'jfKfPfyJRdk', 
            title: 'Lo-Fi Chill Study Beats (Mock Track)', 
            channelTitle: 'Lofi Chilled Records', 
            thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
          ),
          Track(
            id: 'dQw4w9WgXcQ', 
            title: 'Synthwave Retro Coding Mix (Mock Track)', 
            channelTitle: 'Synth Records', 
            thumbnailUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=150',
          ),
          Track(
            id: '9FvvbVI5rY0', 
            title: 'Acoustic Coffee Shop Guitar (Mock Track)', 
            channelTitle: 'The Acoustic Club', 
            thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150',
          ),
          Track(
            id: '9FvvbVI5rY0', 
            title: 'Acoustic Coffee Shop Guitar (Mock Track)', 
            channelTitle: 'The Acoustic Club', 
            thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150',
          ),
          Track(
            id: '9FvvbVI5rY0', 
            title: 'Acoustic Coffee Shop Guitar (Mock Track)', 
            channelTitle: 'The Acoustic Club', 
            thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150',
          ),
        ];
      }

      // === STRATEGY 1: LOCAL IN-MEMORY CACHE ===
      if (_searchCache.containsKey(cleanQuery)) {
        print("🎯 CACHE HIT: Quota Saved! Pulling '$cleanQuery' from local memory.");
        return _searchCache[cleanQuery]!;
      }

      // === LIVE NETWORK CALL (Only hits if cache misses and debugMode is false) ===
      print("🌐 CACHE MISS: Making a live 100-unit search request for '$cleanQuery'...");
      final String url = 
          'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=5&q=$cleanQuery%20audio&type=video&videoDuration=medium&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['items'];
        
        final List<Track> tracks = items.map((item) => Track.fromJson(item)).toList();
        
        // Save to cache memory map
        _searchCache[cleanQuery] = tracks;
        return tracks;
      } else {
        throw Exception('Failed to load music from YouTube. Check your API Key.');
      }
    }
}