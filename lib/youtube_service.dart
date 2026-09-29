import 'dart:convert';
import 'track_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Import your track model here if it is in a separate file

class YouTubeService {
  Future<List<Track>> searchMusic(String query) async {
    // Looks for the exact variable name you used in Codemagic
    final apiKey = dotenv.env['YOUTUBEAPI']; 
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key is missing from .env file');
    }

    // YouTube API Endpoint (Filtered for Music Category 10)
    final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=15&q=$query&type=video&videoCategoryId=10&key=$apiKey');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List items = data['items'] ?? [];
      
      return items.map((item) {
        final snippet = item['snippet'] ?? {};
        final thumbnails = snippet['thumbnails'] ?? {};
        final highRes = thumbnails['high'] ?? thumbnails['medium'] ?? thumbnails['default'] ?? {};
        
        return Track(
          id: item['id']['videoId'] ?? '',
          title: snippet['title'] ?? 'Unknown Title',
          channelTitle: snippet['channelTitle'] ?? 'Unknown Artist',
          thumbnailUrl: highRes['url'] ?? 'https://via.placeholder.com/150', // Fallback image
        );
      }).toList();
    } else {
      throw Exception('Network Error: ${response.statusCode}');
    }
  }
}