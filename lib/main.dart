import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'youtube_service.dart';
import 'track_model.dart';
import 'app_colors.dart';
import 'playlist_model.dart';
import 'playlist_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      title: 'Rhythmic',
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

  const MainDashboard({
    super.key,
    required this.activeTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final YouTubeService _apiService = YouTubeService();
  final PlaylistService _playlistService = PlaylistService();
  final TextEditingController _searchController = TextEditingController();

  YoutubePlayerController? _playerController;
  List<Track> _searchResults = [];
  String _currentView = 'search'; 

  Playlist? _selectedPlaylistDetail;
  List<Playlist> _myPlaylists = [];

  bool _isEditingOrder = false;
  final List<Track> _selectedForReorder = [];

  Track? _currentTrack;
  
  // Media Control State
  Playlist? _activePlaylist;
  Track? _playlistAnchor; // Remembers our place in the playlist when playing queued tracks
  final List<Track> _queue = []; // The manual queue
  
  bool _isLooping = false;
  bool _isShuffling = false;
  double _globalVolume = 100.0; 
  
  PlayerState _lastPlayerState = PlayerState.unknown;
  Timer? _mainTicker;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaylists();

    _playerController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
      ),
    );

    _startBackgroundStateWatcher();
  }

  void _startBackgroundStateWatcher() {
    _mainTicker = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted || _playerController == null) return;

      try {
        final state = await _playerController!.playerState;
        if (mounted) {
          if (state == PlayerState.ended && _lastPlayerState != PlayerState.ended) {
            _handleTrackEnded();
          }
          _lastPlayerState = state;
        }
      } catch (e) {
        // Ignore iframe communication errors while loading
      }
    });
  }

  @override
  void dispose() {
    _mainTicker?.cancel();
    _playerController?.close();
    super.dispose();
  }

  void _handleTrackEnded() {
    if (_isLooping) {
      _playerController!.seekTo(seconds: 0.0);
      _playerController!.playVideo();
      return;
    }

    // Always attempt to play next (Queue gets priority, then Playlist)
    _playNextTrack();
  }

  void _playNextTrack() {
    // 1. QUEUE TAKES PRIORITY
    if (_queue.isNotEmpty) {
      final nextTrack = _queue.removeAt(0);
      setState(() {
        _currentTrack = nextTrack;
        // Notice we do NOT change _activePlaylist or _playlistAnchor. 
        // This lets the app remember where it was in the playlist!
      });
      _playerController?.loadVideoById(videoId: nextTrack.id);
      _playerController?.playVideo();
      return;
    }

    // 2. FALLBACK TO PLAYLIST
    if (_activePlaylist == null || _playlistAnchor == null) return;
    final tracks = _activePlaylist!.tracks;
    if (tracks.isEmpty) return;

    if (_isShuffling) {
      final random = Random();
      Track nextTrack = tracks[random.nextInt(tracks.length)];
      if (tracks.length > 1 && nextTrack.id == _playlistAnchor!.id) {
        int idx;
        do {
          idx = random.nextInt(tracks.length);
        } while (tracks[idx].id == _playlistAnchor!.id);
        nextTrack = tracks[idx];
      }
      setState(() {
        _currentTrack = nextTrack;
        _playlistAnchor = nextTrack; // Update anchor
      });
      _playerController?.loadVideoById(videoId: nextTrack.id);
      _playerController?.playVideo();
    } else {
      // Find where we left off using the Anchor
      int currentIndex = tracks.indexWhere((t) => t.id == _playlistAnchor!.id);
      if (currentIndex != -1 && currentIndex < tracks.length - 1) {
        final nextTrack = tracks[currentIndex + 1];
        setState(() {
          _currentTrack = nextTrack;
          _playlistAnchor = nextTrack; // Update anchor
        });
        _playerController?.loadVideoById(videoId: nextTrack.id);
        _playerController?.playVideo();
      } else {
        // Loop back to the start of the playlist
        final nextTrack = tracks.first;
        setState(() {
          _currentTrack = nextTrack;
          _playlistAnchor = nextTrack; // Update anchor
        });
        _playerController?.loadVideoById(videoId: nextTrack.id);
        _playerController?.playVideo();
      }
    }
  }

  void _playPreviousTrack() {
    if (_activePlaylist == null || _playlistAnchor == null) return;
    final tracks = _activePlaylist!.tracks;
    if (tracks.isEmpty) return;

    int currentIndex = tracks.indexWhere((t) => t.id == _playlistAnchor!.id);
    if (currentIndex > 0) {
      final prevTrack = tracks[currentIndex - 1];
      setState(() {
        _currentTrack = prevTrack;
        _playlistAnchor = prevTrack; // Update anchor
      });
      _playerController?.loadVideoById(videoId: prevTrack.id);
      _playerController?.playVideo();
    } else {
      final prevTrack = tracks.last;
      setState(() {
        _currentTrack = prevTrack;
        _playlistAnchor = prevTrack; // Update anchor
      });
      _playerController?.loadVideoById(videoId: prevTrack.id);
      _playerController?.playVideo();
    }
  }

  void _playTrack(Track track, {Playlist? playlist, bool showScreen = true}) {
    setState(() {
      _currentTrack = track;
      _activePlaylist = playlist;
      
      // Explicitly playing a new track clears the manual queue
      _queue.clear(); 
      
      if (playlist != null) {
        _playlistAnchor = track;
      } else {
        _playlistAnchor = null;
      }
    });

    _playerController?.loadVideoById(videoId: track.id);
    _playerController?.playVideo();
    
    if (showScreen) {
      _openFullPlayerScreen();
    }
  }

  void _loadSavedPlaylists() async {
    final savedPlaylists = await _playlistService.loadPlaylists();
    setState(() {
      _myPlaylists = savedPlaylists;
    });
  }

  void _createNewPlaylist(String name, {Track? initialTrack}) async {
    if (name.isEmpty) return;
    
    try {
      final newPlaylist = Playlist(
        name: name, 
        tracks: initialTrack != null ? [initialTrack] : [],
      );
      
      setState(() {
        _myPlaylists.add(newPlaylist);
      });
      
      try {
        // Your database or network request that is silently failing
        await _playlistService.savePlaylists(_myPlaylists);
      } catch (e) {
        // Remove this:
        // print('Error saving playlist: $e');
        print('Error saving playlist: $e. This is a silent failure that will now be rethrown.');
        // Add this:
        rethrow; 
      }

      if (initialTrack != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to ${newPlaylist.name}')),
        );
      }
    } catch (e) {
      // This will force the invisible iOS error onto your screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CRASH: $e'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _addTrackToPlaylist(Track track, Playlist playlist) async {
    setState(() {
      playlist.tracks.add(track);
    });
    try {
      await _playlistService.savePlaylists(_myPlaylists);
    } catch (e) {

      rethrow; 
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to ${playlist.name}')),
      );
    }
  }

  void _executeSearch(String query) async {
    if (query.isEmpty) return;
    final results = await _apiService.searchMusic(query);
    setState(() {
      _searchResults = results;
      _currentView = 'search';
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // === UPDATED: UNIVERSAL TRACK MENU (Queue, Create, Add) ===
  void _showTrackMenu(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.activeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Track Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // 1. ADD TO QUEUE
              ListTile(
                leading: Icon(Icons.queue_music, color: widget.activeTheme.primaryAccent),
                title: Text(
                  'Add to Queue',
                  style: TextStyle(color: widget.activeTheme.primaryAccent, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  setState(() {
                    _queue.add(track);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to Queue to play next')),
                  );
                },
              ),
              
              const Divider(color: Colors.grey),

              // 2. CREATE NEW PLAYLIST (With Track)
              ListTile(
                leading: Icon(Icons.add_box, color: widget.activeTheme.textPrimary),
                title: Text(
                  'Create New Playlist',
                  style: TextStyle(color: widget.activeTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showCreatePlaylistDialog(context, trackToAdd: track);
                },
              ),
              
              const Divider(color: Colors.grey),

              // 3. ADD TO EXISTING PLAYLIST
              _myPlaylists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No existing playlists.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _myPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist = _myPlaylists[index];
                          final bool isAlreadyAdded = playlist.tracks.any((t) => t.id == track.id);

                          return ListTile(
                            enabled: !isAlreadyAdded,
                            leading: Icon(
                              Icons.playlist_add,
                              color: isAlreadyAdded
                                  ? widget.activeTheme.textSecondary.withOpacity(0.5)
                                  : widget.activeTheme.textPrimary,
                            ),
                            title: Text(
                              playlist.name,
                              style: TextStyle(
                                color: isAlreadyAdded
                                    ? widget.activeTheme.textSecondary
                                    : widget.activeTheme.textPrimary,
                              ),
                            ),
                            subtitle: isAlreadyAdded
                                ? const Text(
                                    'Already in playlist',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  )
                                : null,
                            trailing: isAlreadyAdded
                                ? Icon(Icons.check_circle, color: widget.activeTheme.primaryAccent, size: 22)
                                : null,
                            onTap: isAlreadyAdded
                                ? null 
                                : () {
                                    Navigator.pop(bottomSheetContext);
                                    _addTrackToPlaylist(track, playlist);
                                  },
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, {Track? trackToAdd}) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: widget.activeTheme.surface,
          title: const Text('New Playlist'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter playlist title...',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: widget.activeTheme.primaryAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text('Create', style: TextStyle(color: widget.activeTheme.primaryAccent)),
              onPressed: () {
                _createNewPlaylist(nameController.text, initialTrack: trackToAdd);
                Navigator.pop(dialogContext);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeletePlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: widget.activeTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to delete "${_selectedPlaylistDetail?.name}"? This action cannot be undone.',
            style: TextStyle(color: widget.activeTheme.textSecondary),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.activeTheme.searchBar,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancel', style: TextStyle(color: widget.activeTheme.textPrimary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        setState(() {
                          _selectedForReorder.clear();
                          _isEditingOrder = false;
                          _myPlaylists.remove(_selectedPlaylistDetail);
                          _currentView = 'playlists';
                        });
                        await _playlistService.savePlaylists(_myPlaylists);
                      },
                      child: const Text('Confirm', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _openFullPlayerScreen() {
    if (_currentTrack == null || _playerController == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: widget.activeTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return FullPlayerModalContent(
          controller: _playerController!,
          getTrack: () => _currentTrack!, 
          activeTheme: widget.activeTheme,
          formatDuration: _formatDuration,
          hasPlaylist: _activePlaylist != null,
          isLooping: _isLooping,
          isShuffling: _isShuffling,
          currentVolume: _globalVolume,
          onVolumeChanged: (val) => setState(() => _globalVolume = val),
          onToggleLoop: (val) => setState(() => _isLooping = val),
          onToggleShuffle: (val) => setState(() => _isShuffling = val),
          onSkipNext: _activePlaylist != null || _queue.isNotEmpty ? _playNextTrack : null,
          onSkipPrevious: _activePlaylist != null ? _playPreviousTrack : null,
          onOptionsTap: () => _showTrackMenu(_currentTrack!), 
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case 'playlists':
        return ListView.builder(
          itemCount: _myPlaylists.length,
          itemBuilder: (context, index) {
            final playlist = _myPlaylists[index];
            return ListTile(
              leading: Icon(Icons.playlist_play, color: widget.activeTheme.primaryAccent, size: 40),
              title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${playlist.tracks.length} songs', style: TextStyle(color: widget.activeTheme.textSecondary)),
              onTap: () {
                setState(() {
                  _selectedPlaylistDetail = playlist;
                  _currentView = 'playlist_detail';
                });
              },
            );
          },
        );

      case 'playlist_detail':
        if (_selectedPlaylistDetail == null) return const Center(child: Text('No playlist selected'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _isEditingOrder = false;
                        _selectedForReorder.clear();
                        _currentView = 'playlists';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditingOrder ? 'Select Order' : _selectedPlaylistDetail!.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  if (_isEditingOrder) ...[
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 26),
                      tooltip: 'Cancel',
                      onPressed: () {
                        setState(() {
                          _selectedForReorder.clear();
                          _isEditingOrder = false;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: widget.activeTheme.primaryAccent, size: 28),
                      tooltip: 'Confirm Order',
                      onPressed: () async {
                        if (_selectedForReorder.isNotEmpty) {
                          setState(() {
                            final unselected = _selectedPlaylistDetail!.tracks
                                .where((t) => !_selectedForReorder.contains(t))
                                .toList();

                            _selectedPlaylistDetail!.tracks.clear();
                            _selectedPlaylistDetail!.tracks.addAll(_selectedForReorder);
                            _selectedPlaylistDetail!.tracks.addAll(unselected);
                          });

                          await _playlistService.savePlaylists(_myPlaylists);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Playlist order updated!')),
                            );
                          }
                        }

                        setState(() {
                          _selectedForReorder.clear();
                          _isEditingOrder = false;
                        });
                      },
                    ),
                  ] else ...[
                    IconButton(
                      icon: Icon(Icons.edit, color: widget.activeTheme.primaryAccent, size: 26),
                      tooltip: 'Edit Playlist Order',
                      onPressed: () {
                        setState(() {
                          _selectedForReorder.clear();
                          _isEditingOrder = true;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.play_arrow_rounded, color: widget.activeTheme.primaryAccent, size: 28),
                      tooltip: 'Play All',
                      onPressed: () {
                        if (_selectedPlaylistDetail!.tracks.isNotEmpty) {
                          _playTrack(_selectedPlaylistDetail!.tracks.first, playlist: _selectedPlaylistDetail);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Delete Playlist',
                      onPressed: () => _showDeletePlaylistDialog(context),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _selectedPlaylistDetail!.tracks.isEmpty
                  ? const Center(child: Text('This playlist is empty.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _selectedPlaylistDetail!.tracks.length,
                      itemBuilder: (context, index) {
                        final track = _selectedPlaylistDetail!.tracks[index];
                        final isSelected = _selectedForReorder.contains(track);
                        final selectIndex = _selectedForReorder.indexOf(track) + 1;

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(track.thumbnailUrl, width: 60, fit: BoxFit.cover),
                          ),
                          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(track.channelTitle),
                          trailing: _isEditingOrder
                              ? (isSelected
                                  ? CircleAvatar(
                                      radius: 14,
                                      backgroundColor: widget.activeTheme.primaryAccent,
                                      child: Text(
                                        '$selectIndex',
                                        style: TextStyle(
                                          color: widget.activeTheme.surface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.circle_outlined, color: Colors.grey))
                              : IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showTrackMenu(track),
                                ),
                          onTap: () {
                            if (_isEditingOrder) {
                              setState(() {
                                if (isSelected) {
                                  _selectedForReorder.remove(track);
                                } else {
                                  _selectedForReorder.add(track);
                                }
                              });
                            } else {
                              _playTrack(track, playlist: _selectedPlaylistDetail);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      case 'search':
      default:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              key: const Key('search_bar_padding'),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: widget.activeTheme.searchBar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: _executeSearch,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final track = _searchResults[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(track.thumbnailUrl, width: 60, fit: BoxFit.cover),
                    ),
                    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(track.channelTitle),
                    trailing: IconButton(
                      icon: Icon(Icons.more_vert, color: widget.activeTheme.primaryAccent),
                      onPressed: () => _showTrackMenu(track),
                    ),
                    onTap: () => _playTrack(track, playlist: null),
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    _playerController ??= YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
      ),
    );

    return YoutubePlayerScaffold(
      controller: _playerController!,
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_currentView == 'search'
                ? 'Search Music'
                : _currentView == 'playlists'
                    ? 'My Playlists'
                    : _selectedPlaylistDetail?.name ?? 'Playlist'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          drawer: Drawer(
            backgroundColor: widget.activeTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: widget.activeTheme.searchBar,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 40, color: widget.activeTheme.primaryAccent),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.home, color: widget.activeTheme.textPrimary),
                  title: const Text('Home / Search'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentView = 'search';
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.playlist_play, color: widget.activeTheme.textPrimary),
                  title: const Text('My Playlists'),
                  subtitle: Text('${_myPlaylists.length} playlists created', style: TextStyle(color: widget.activeTheme.textSecondary)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentView = 'playlists';
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.add_box, color: widget.activeTheme.primaryAccent),
                  title: const Text('Create New Playlist'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(context);
                  },
                ),
                const Divider(color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Material(
                    color: widget.activeTheme.searchBar,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.activeTheme.primaryAccent.withOpacity(0.3)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Icon(Icons.palette, color: widget.activeTheme.primaryAccent),
                          title: Text(
                            'Active Theme Layout',
                            style: TextStyle(color: widget.activeTheme.textPrimary, fontSize: 16),
                          ),
                          iconColor: widget.activeTheme.primaryAccent,
                          collapsedIconColor: widget.activeTheme.primaryAccent,
                          childrenPadding: const EdgeInsets.only(left: 16.0),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lens, color: Colors.deepPurpleAccent, size: 18),
                              title: const Text('Deep Purple'),
                              selected: widget.activeTheme == AppColors.deepPurple,
                              onTap: () => widget.onThemeChanged(AppColors.deepPurple),
                            ),
                            ListTile(
                              leading: const Icon(Icons.lens, color: Colors.cyanAccent, size: 18),
                              title: const Text('Cyber Blue'),
                              selected: widget.activeTheme == AppColors.cyberBlue,
                              onTap: () => widget.onThemeChanged(AppColors.cyberBlue),
                            ),
                            ListTile(
                              leading: const Icon(Icons.lens, color: Colors.greenAccent, size: 18),
                              title: const Text('Forest Mint'),
                              selected: widget.activeTheme == AppColors.forestMint,
                              onTap: () => widget.onThemeChanged(AppColors.forestMint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: widget.activeTheme.textPrimary),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0.01,
                  child: player,
                ),
              ),
              Column(
                children: [
                  Expanded(child: _buildBody()),
                  if (_currentTrack != null)
                    MiniPlayer(
                      controller: _playerController!,
                      track: _currentTrack!,
                      activeTheme: widget.activeTheme,
                      onTap: _openFullPlayerScreen,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class FullPlayerModalContent extends StatefulWidget {
  final YoutubePlayerController controller;
  final Track Function() getTrack;
  final AppColors activeTheme;
  final String Function(Duration) formatDuration;
  final bool hasPlaylist;
  final bool isLooping;
  final bool isShuffling;
  final double currentVolume;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool> onToggleLoop;
  final ValueChanged<bool> onToggleShuffle;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onOptionsTap;

  const FullPlayerModalContent({
    super.key,
    required this.controller,
    required this.getTrack,
    required this.activeTheme,
    required this.formatDuration,
    required this.hasPlaylist,
    required this.isLooping,
    required this.isShuffling,
    required this.currentVolume,
    required this.onVolumeChanged,
    required this.onToggleLoop,
    required this.onToggleShuffle,
    this.onSkipNext,
    this.onSkipPrevious,
    this.onOptionsTap,
  });

  @override
  State<FullPlayerModalContent> createState() => _FullPlayerModalContentState();
}

class _FullPlayerModalContentState extends State<FullPlayerModalContent> {
  late Track _localTrack;
  double _currentSeconds = 0.0;
  Duration _duration = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isPlaying = true;
  
  late double _localVolume;
  late bool _localIsLooping;
  late bool _localIsShuffling;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _localTrack = widget.getTrack();
    _localIsLooping = widget.isLooping;
    _localIsShuffling = widget.isShuffling;
    _localVolume = widget.currentVolume;
    _startSyncTimer();
  }

  void _startSyncTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;

      double tempCurTime = _currentSeconds;
      double tempDurSeconds = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
      PlayerState tempState = _isPlaying ? PlayerState.playing : PlayerState.unknown;

      try {
        tempState = await widget.controller.playerState;
      } catch (_) {}

      try {
        final meta = widget.controller.value.metaData;
        if (meta.duration.inSeconds > 0) {
          tempDurSeconds = meta.duration.inMilliseconds / 1000.0;
        } else {
          tempDurSeconds = await widget.controller.duration;
        }
      } catch (e) {
        final match = RegExp(r'([0-9.]+):\s*type').firstMatch(e.toString());
        if (match != null) {
          tempDurSeconds = double.tryParse(match.group(1)!) ?? tempDurSeconds;
        }
      }

      try {
        tempCurTime = await widget.controller.currentTime;
      } catch (e) {
        final match = RegExp(r'([0-9.]+):\s*type').firstMatch(e.toString());
        if (match != null) {
          tempCurTime = double.tryParse(match.group(1)!) ?? tempCurTime;
        } else if (tempState == PlayerState.playing) {
          tempCurTime += 0.5;
        }
      }

      final latestTrack = widget.getTrack();

      if (mounted) {
        setState(() {
          if (latestTrack.id != _localTrack.id) {
            _localTrack = latestTrack;
            tempCurTime = 0.0;
          }
          if (!_isDragging && tempDurSeconds > 0) {
            _currentSeconds = tempCurTime.clamp(0.0, tempDurSeconds);
          }
          if (tempDurSeconds > 0) {
            _duration = Duration(milliseconds: (tempDurSeconds * 1000).round());
          }
          
          if (tempState == PlayerState.playing || tempState == PlayerState.buffering) {
            _isPlaying = true;
          } else if (tempState == PlayerState.paused || tempState == PlayerState.ended) {
            _isPlaying = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxSeconds = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final double activeSliderValue = (_isDragging ? _dragValue : _currentSeconds).clamp(0.0, maxSeconds);
    final Duration currentPosition = Duration(seconds: activeSliderValue.toInt());
    
    final bool isMobile = Theme.of(context).platform == TargetPlatform.android || 
                          Theme.of(context).platform == TargetPlatform.iOS;

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),

              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.activeTheme.primaryAccent.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      _localTrack.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _localTrack.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _localTrack.channelTitle,
                  style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 15),
                ),
              ),

              const SizedBox(height: 16),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  activeTrackColor: widget.activeTheme.primaryAccent,
                  inactiveTrackColor: widget.activeTheme.searchBar,
                  thumbColor: widget.activeTheme.primaryAccent,
                ),
                child: Slider(
                  value: activeSliderValue,
                  min: 0.0,
                  max: maxSeconds,
                  onChangeStart: (val) {
                    setState(() {
                      _isDragging = true;
                      _dragValue = val;
                    });
                  },
                  onChanged: (val) {
                    setState(() {
                      _dragValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    widget.controller.seekTo(seconds: val, allowSeekAhead: true);
                    setState(() {
                      _currentSeconds = val;
                      _isDragging = false;
                    });
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.formatDuration(currentPosition),
                      style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12),
                    ),
                    Text(
                      widget.formatDuration(_duration),
                      style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // VOLUME SLIDER (ONLY VISIBLE IF NOT ON MOBILE)
              if (!isMobile) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(
                        _localVolume == 0 ? Icons.volume_off : Icons.volume_down,
                        color: widget.activeTheme.textSecondary,
                        size: 20,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                            activeTrackColor: widget.activeTheme.textPrimary,
                            inactiveTrackColor: widget.activeTheme.searchBar,
                            thumbColor: widget.activeTheme.textPrimary,
                          ),
                          child: Slider(
                            value: _localVolume,
                            min: 0.0,
                            max: 100.0,
                            onChanged: (val) {
                              setState(() {
                                _localVolume = val;
                              });
                              widget.controller.setVolume(val.round()); 
                              widget.onVolumeChanged(val);
                            },
                          ),
                        ),
                      ),
                      Icon(
                        Icons.volume_up,
                        color: widget.activeTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // MAIN PLAYBACK CONTROLS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.skip_previous),
                    color: widget.hasPlaylist ? Colors.white : Colors.grey.withOpacity(0.3),
                    onPressed: widget.onSkipPrevious,
                  ),
                  IconButton(
                    iconSize: 28,
                    icon: const Icon(Icons.replay),
                    color: Colors.white,
                    onPressed: () {
                      final newTime = (_currentSeconds - 15).clamp(0.0, maxSeconds);
                      widget.controller.seekTo(seconds: newTime, allowSeekAhead: true);
                      setState(() => _currentSeconds = newTime);
                    },
                  ),
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: widget.activeTheme.primaryAccent,
                    child: IconButton(
                      iconSize: 32,
                      color: widget.activeTheme.background,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        final wasPlaying = _isPlaying;
                        setState(() => _isPlaying = !wasPlaying);

                        if (wasPlaying) {
                          widget.controller.pauseVideo();
                        } else {
                          widget.controller.playVideo();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    iconSize: 28,
                    icon: const Icon(Icons.forward_30),
                    color: Colors.white,
                    onPressed: () {
                      final newTime = (_currentSeconds + 30).clamp(0.0, maxSeconds);
                      widget.controller.seekTo(seconds: newTime, allowSeekAhead: true);
                      setState(() => _currentSeconds = newTime);
                    },
                  ),
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.skip_next),
                    // Enable next if we are in a playlist OR there are items in the queue
                    color: widget.onSkipNext != null ? Colors.white : Colors.grey.withOpacity(0.3),
                    onPressed: widget.onSkipNext,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // SECONDARY CONTROLS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          iconSize: 24,
                          icon: const Icon(Icons.shuffle),
                          color: widget.hasPlaylist 
                              ? (_localIsShuffling ? widget.activeTheme.primaryAccent : Colors.grey)
                              : Colors.grey.withOpacity(0.3),
                          onPressed: widget.hasPlaylist ? () {
                            setState(() => _localIsShuffling = !_localIsShuffling);
                            widget.onToggleShuffle(_localIsShuffling);
                          } : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 28, color: Colors.grey),
                      color: widget.activeTheme.searchBar,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      position: PopupMenuPosition.over,
                      onSelected: (value) {
                        if (value == 'options' && widget.onOptionsTap != null) {
                          // Call the master track menu we just built!
                          widget.onOptionsTap!();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$value clicked!')),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'options',
                          child: Row(
                            children: [
                              Icon(Icons.menu_open, color: widget.activeTheme.primaryAccent),
                              const SizedBox(width: 12),
                              Text('Track Options', style: TextStyle(color: widget.activeTheme.textPrimary)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'View Artist',
                          child: Row(
                            children: [
                              Icon(Icons.person, color: widget.activeTheme.primaryAccent),
                              const SizedBox(width: 12),
                              Text('View Artist', style: TextStyle(color: widget.activeTheme.textPrimary)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'Share',
                          child: Row(
                            children: [
                              Icon(Icons.ios_share, color: widget.activeTheme.primaryAccent),
                              const SizedBox(width: 12),
                              Text('Share Track', style: TextStyle(color: widget.activeTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          iconSize: 24,
                          icon: const Icon(Icons.loop),
                          color: _localIsLooping ? widget.activeTheme.primaryAccent : Colors.grey,
                          onPressed: () {
                            setState(() => _localIsLooping = !_localIsLooping);
                            widget.onToggleLoop(_localIsLooping);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniPlayer extends StatefulWidget {
  final YoutubePlayerController controller;
  final Track track;
  final AppColors activeTheme;
  final VoidCallback onTap;

  const MiniPlayer({
    super.key,
    required this.controller,
    required this.track,
    required this.activeTheme,
    required this.onTap,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  double _currentSeconds = 0.0;
  double _durationSeconds = 1.0;
  bool _isPlaying = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSyncTimer();
  }

  void _startSyncTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;

      double tempCurTime = _currentSeconds;
      double tempDurSeconds = _durationSeconds;
      PlayerState tempState = _isPlaying ? PlayerState.playing : PlayerState.unknown;

      try {
        tempState = await widget.controller.playerState;
      } catch (_) {}

      try {
        final meta = widget.controller.value.metaData;
        if (meta.duration.inSeconds > 0) {
          tempDurSeconds = meta.duration.inMilliseconds / 1000.0;
        } else {
          tempDurSeconds = await widget.controller.duration;
        }
      } catch (e) {
        final match = RegExp(r'([0-9.]+):\s*type').firstMatch(e.toString());
        if (match != null) {
          tempDurSeconds = double.tryParse(match.group(1)!) ?? tempDurSeconds;
        }
      }

      try {
        tempCurTime = await widget.controller.currentTime;
      } catch (e) {
        final match = RegExp(r'([0-9.]+):\s*type').firstMatch(e.toString());
        if (match != null) {
          tempCurTime = double.tryParse(match.group(1)!) ?? tempCurTime;
        } else if (tempState == PlayerState.playing) {
          tempCurTime += 0.5;
        }
      }

      if (mounted && tempDurSeconds > 0) {
        setState(() {
          if (tempCurTime < _currentSeconds && (_currentSeconds - tempCurTime) > 5) {
            _currentSeconds = tempCurTime;
          } else {
            _currentSeconds = tempCurTime.clamp(0.0, tempDurSeconds);
          }
          
          _durationSeconds = tempDurSeconds;
          
          if (tempState == PlayerState.playing || tempState == PlayerState.buffering) {
            _isPlaying = true;
          } else if (tempState == PlayerState.paused || tempState == PlayerState.ended) {
            _isPlaying = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_durationSeconds > 0) 
        ? (_currentSeconds / _durationSeconds).clamp(0.0, 1.0) 
        : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: widget.activeTheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: widget.activeTheme.searchBar,
              valueColor: AlwaysStoppedAnimation<Color>(widget.activeTheme.primaryAccent),
              minHeight: 2.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      widget.track.thumbnailUrl,
                      width: 50,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.track.channelTitle,
                          style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      final wasPlaying = _isPlaying;
                      setState(() => _isPlaying = !wasPlaying);

                      if (wasPlaying) {
                        widget.controller.pauseVideo();
                      } else {
                        widget.controller.playVideo();
                      }
                    },
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