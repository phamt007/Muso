import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'track_model.dart';

class YouTubeService {
  final YoutubeExplode _ytExplode = YoutubeExplode();

  Future<List<Track>> searchMusic(String query) async {
    final searchResults = await _ytExplode.search.search(query, filter: SortFilters.viewCount);
    
    return searchResults.map((video) => Track(
      id: video.id.value,
      title: video.title,
      channelTitle: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
    )).toList();
  }
}