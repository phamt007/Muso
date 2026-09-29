import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ADD "hide Playlist" TO THIS LINE:
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist; 

import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import 'youtube_service.dart';
import 'track_model.dart';
import 'playlist_model.dart';

// === DUMMY DATA MODELS ===
class AppColors {
  final Color background;
  final Color surface;
  final Color primaryAccent;
  final Color searchBar;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.background,
    required this.surface,
    required this.primaryAccent,
    required this.searchBar,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const deepPurple = AppColors(background: Color(0xFF121212), surface: Color(0xFF1E1E1E), primaryAccent: Colors.deepPurpleAccent, searchBar: Color(0xFF2C2C2C), textPrimary: Colors.white, textSecondary: Colors.grey);
  static const cyberBlue = AppColors(background: Color(0xFF0A0F24), surface: Color(0xFF111936), primaryAccent: Colors.cyanAccent, searchBar: Color(0xFF1A264F), textPrimary: Colors.white, textSecondary: Colors.grey);
  static const forestMint = AppColors(background: Color(0xFF0F1A15), surface: Color(0xFF16261E), primaryAccent: Colors.greenAccent, searchBar: Color(0xFF1F362A), textPrimary: Colors.white, textSecondary: Colors.grey);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MusicApp());
}

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  AppColors _activeTheme = AppColors.deepPurple;

  void _updateTheme(AppColors newTheme) {
    setState(() {
      _activeTheme = newTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rhythmic Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _activeTheme.background,
      ),
      home: MainDashboard(
        activeTheme: _activeTheme,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  final AppColors activeTheme;
  final ValueChanged<AppColors> onThemeChanged;

  const MainDashboard({super.key, required this.activeTheme, required this.onThemeChanged});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final YouTubeService _apiService = YouTubeService();
  final TextEditingController _searchController = TextEditingController();
  
  // === NATIVE AUDIO ENGINES ===
  final AudioPlayer _audioPlayer = AudioPlayer();
  final YoutubeExplode _ytExplode = YoutubeExplode();

  List<Track> _searchResults = [];
  String _currentView = 'search';
  Playlist? _selectedPlaylistDetail;
  final List<Playlist> _myPlaylists = [];
  bool _isEditingOrder = false;
  final List<Track> _selectedForReorder = [];

  Track? _currentTrack;
  Playlist? _activePlaylist;
  Track? _playlistAnchor;
  final List<Track> _queue = [];

  bool _isShuffling = false;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    
    // Listen for when a track naturally finishes to play the next one
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNextTrack();
      }
    });
  }

  Future<void> _initAudioSession() async {
    // This tells iOS: "I am a music app, don't kill me when the screen locks!"
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _ytExplode.close();
    super.dispose();
  }

  void _showDebugNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16), 
      ),
    );
  }

  void _playNextTrack() {
    if (_queue.isNotEmpty) {
      _playTrack(_queue.removeAt(0), showScreen: false);
      return;
    }
    if (_activePlaylist == null || _playlistAnchor == null) return;
    final tracks = _activePlaylist!.tracks;
    if (tracks.isEmpty) return;

    if (_isShuffling) {
      final random = Random();
      _playTrack(tracks[random.nextInt(tracks.length)], playlist: _activePlaylist, showScreen: false);
    } else {
      int currentIndex = tracks.indexWhere((t) => t.id == _playlistAnchor!.id);
      if (currentIndex != -1 && currentIndex < tracks.length - 1) {
        _playTrack(tracks[currentIndex + 1], playlist: _activePlaylist, showScreen: false);
      } else {
        _playTrack(tracks.first, playlist: _activePlaylist, showScreen: false);
      }
    }
  }

  void _playPreviousTrack() {
    if (_activePlaylist == null || _playlistAnchor == null) return;
    final tracks = _activePlaylist!.tracks;
    if (tracks.isEmpty) return;

    int currentIndex = tracks.indexWhere((t) => t.id == _playlistAnchor!.id);
    if (currentIndex > 0) {
      _playTrack(tracks[currentIndex - 1], playlist: _activePlaylist, showScreen: false);
    } else {
      _playTrack(tracks.last, playlist: _activePlaylist, showScreen: false);
    }
  }

  // === THE NEW SCRAPING & PLAYBACK LOGIC ===
  Future<void> _playTrack(Track track, {Playlist? playlist, bool showScreen = true}) async {
    setState(() {
      _currentTrack = track;
      _activePlaylist = playlist;
      _queue.clear();
      _playlistAnchor = playlist != null ? track : null;
    });

    _showDebugNotification('Extracting stream for: ${track.title}...');

    try {
      // 1. Ask YoutubeExplode to get the backend manifest for this video ID
      var manifest = await _ytExplode.videos.streamsClient.getManifest(track.id);
      
      // 2. Filter out the video and get the highest bitrate audio file
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      
      // 3. Pass that raw URL to the native iOS audio player
      await _audioPlayer.setUrl(audioStreamInfo.url.toString());
      _audioPlayer.play();
      
      _showDebugNotification('Playing natively: ${track.title}');
    } catch (e) {
      _showDebugNotification('Stream Extraction Error: $e');
    }

    if (showScreen) {
      _openFullPlayerScreen();
    }
  }

  void _createNewPlaylist(String name, {Track? initialTrack}) {
    if (name.isEmpty) return;
    final newPlaylist = Playlist(name: name, tracks: initialTrack != null ? [initialTrack] : []);
    setState(() => _myPlaylists.add(newPlaylist));
    if (initialTrack != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${newPlaylist.name}')));
    }
  }

  void _addTrackToPlaylist(Track track, Playlist playlist) {
    setState(() => playlist.tracks.add(track));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${playlist.name}')));
  }

  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) return;
    _showDebugNotification('Searching...');
    try {
      final results = await _apiService.searchMusic(query);
      setState(() {
        _searchResults = results;
        _currentView = 'search';
      });
    } catch (e) {
      _showDebugNotification('ERROR: $e');
    }
  }

  void _showTrackMenu(Track track) {
    // (Omitted for brevity, paste your _showTrackMenu here!)
  }

  void _showCreatePlaylistDialog(BuildContext context, {Track? trackToAdd}) {
    // (Omitted for brevity, paste your _showCreatePlaylistDialog here!)
  }

  void _showDeletePlaylistDialog(BuildContext context) {
    // (Omitted for brevity, paste your _showDeletePlaylistDialog here!)
  }

  void _openFullPlayerScreen() {
    if (_currentTrack == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.activeTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return FullPlayerModalContent(
          player: _audioPlayer, // Pass the native player
          track: _currentTrack!,
          activeTheme: widget.activeTheme,
          hasPlaylist: _activePlaylist != null,
          isShuffling: _isShuffling,
          onToggleLoop: (val) {
            _audioPlayer.setLoopMode(val ? LoopMode.one : LoopMode.off);
          },
          onToggleShuffle: (val) => setState(() => _isShuffling = val),
          onSkipNext: _activePlaylist != null || _queue.isNotEmpty ? _playNextTrack : null,
          onSkipPrevious: _activePlaylist != null ? _playPreviousTrack : null,
          onOptionsTap: () => _showTrackMenu(_currentTrack!),
        );
      },
    );
  }

  Widget _buildBody() {
    // (Omitted for brevity - paste your EXACT _buildBody from before. It doesn't need to change!)
    return Center(child: Text("Paste your _buildBody here!"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rhythmic Background Audio'), backgroundColor: Colors.transparent, elevation: 0),
      drawer: Drawer(
        backgroundColor: widget.activeTheme.surface,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: widget.activeTheme.searchBar),
              child: const Center(child: Text('Rhythmic Prototype', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ),
            ListTile(title: const Text('Home / Search'), onTap: () { Navigator.pop(context); setState(() => _currentView = 'search'); }),
            ListTile(title: const Text('My Playlists'), onTap: () { Navigator.pop(context); setState(() => _currentView = 'playlists'); }),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_currentTrack != null)
            MiniPlayer(
              player: _audioPlayer,
              track: _currentTrack!,
              activeTheme: widget.activeTheme,
              onTap: _openFullPlayerScreen,
            ),
        ],
      ),
    );
  }
}

// === FULL PLAYER USING JUST_AUDIO ===
class FullPlayerModalContent extends StatelessWidget {
  final AudioPlayer player;
  final Track track;
  final AppColors activeTheme;
  final bool hasPlaylist;
  final bool isShuffling;
  final ValueChanged<bool> onToggleLoop;
  final ValueChanged<bool> onToggleShuffle;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onOptionsTap;

  const FullPlayerModalContent({
    super.key,
    required this.player,
    required this.track,
    required this.activeTheme,
    required this.hasPlaylist,
    required this.isShuffling,
    required this.onToggleLoop,
    required this.onToggleShuffle,
    this.onSkipNext,
    this.onSkipPrevious,
    this.onOptionsTap,
  });

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)))),
              Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 30), onPressed: () => Navigator.pop(context))),
              const Spacer(),
              
              // ALBUM ART
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: activeTheme.primaryAccent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: track.thumbnailUrl.isNotEmpty
                      ? Image.network(track.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.music_note, size: 120, color: activeTheme.primaryAccent))
                      : Container(color: activeTheme.searchBar, child: Icon(Icons.music_note, size: 120, color: activeTheme.primaryAccent)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // TITLES
              Align(alignment: Alignment.centerLeft, child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: Text(track.channelTitle, style: TextStyle(color: activeTheme.textSecondary, fontSize: 15))),
              const SizedBox(height: 16),
              
              // SEEK BAR
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = player.duration ?? Duration.zero;
                  
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          activeTrackColor: activeTheme.primaryAccent,
                          inactiveTrackColor: activeTheme.searchBar,
                          thumbColor: activeTheme.primaryAccent,
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble(),
                          min: 0.0,
                          max: (duration.inSeconds > 0) ? duration.inSeconds.toDouble() : 1.0,
                          onChanged: (val) {
                            player.seek(Duration(seconds: val.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position), style: TextStyle(color: activeTheme.textSecondary, fontSize: 12)),
                            Text(_formatDuration(duration), style: TextStyle(color: activeTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              ),
              const Spacer(),
              
              // MAIN CONTROLS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(iconSize: 32, icon: const Icon(Icons.skip_previous), color: hasPlaylist ? Colors.white : Colors.grey.withOpacity(0.3), onPressed: onSkipPrevious),
                  
                  // PLAY/PAUSE SYNCED WITH NATIVE PLAYER
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;
                      return CircleAvatar(
                        radius: 32,
                        backgroundColor: activeTheme.primaryAccent,
                        child: IconButton(
                          iconSize: 32,
                          color: activeTheme.background,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (playing) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                        ),
                      );
                    }
                  ),
                  
                  IconButton(iconSize: 32, icon: const Icon(Icons.skip_next), color: onSkipNext != null ? Colors.white : Colors.grey.withOpacity(0.3), onPressed: onSkipNext),
                ],
              ),
              const SizedBox(height: 16),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// === MINI PLAYER USING JUST_AUDIO ===
class MiniPlayer extends StatelessWidget {
  final AudioPlayer player;
  final Track track;
  final AppColors activeTheme;
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.player, required this.track, required this.activeTheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: activeTheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PROGRESS BAR
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data?.inSeconds.toDouble() ?? 0.0;
                final duration = player.duration?.inSeconds.toDouble() ?? 1.0;
                return LinearProgressIndicator(
                  value: (duration > 0) ? position / duration : 0.0,
                  backgroundColor: activeTheme.searchBar,
                  valueColor: AlwaysStoppedAnimation<Color>(activeTheme.primaryAccent),
                  minHeight: 2.0,
                );
              }
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(track.thumbnailUrl, width: 50, height: 45, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.music_note, color: activeTheme.primaryAccent)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(track.channelTitle, style: TextStyle(color: activeTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  // MINI PLAY/PAUSE
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (playing) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                      );
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}