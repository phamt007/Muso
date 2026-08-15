
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'youtube_service.dart';
import 'track_model.dart';
import 'app_colors.dart';
import 'playlist_model.dart';
import 'playlist_service.dart';

void main() => runApp(const MusicApp());

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

  @override
  void initState() {
    super.initState();
    _loadSavedPlaylists();
  }

  void _loadSavedPlaylists() async {
    final savedPlaylists = await _playlistService.loadPlaylists();
    setState(() {
      _myPlaylists = savedPlaylists;
    });
  }

  void _createNewPlaylist(String name) async {
    if (name.isEmpty) return;
    final newPlaylist = Playlist(name: name, tracks: []);
    setState(() {
      _myPlaylists.add(newPlaylist);
    });
    await _playlistService.savePlaylists(_myPlaylists);
  }

  void _addTrackToPlaylist(Track track, Playlist playlist) async {
    setState(() {
      playlist.tracks.add(track);
    });
    await _playlistService.savePlaylists(_myPlaylists);
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

  void _playTrack(Track track) {
    setState(() {
      _currentTrack = track;
      if (_playerController == null) {
        _playerController = YoutubePlayerController(
          params: const YoutubePlayerParams(
            showControls: false,
            showFullscreenButton: false,
            mute: false,
          ),
        );
      }
      _playerController!.loadVideoById(videoId: track.id);
    });
    _openFullPlayerScreen();
  }

  String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
  }

  void _showPlaylistSelector(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.activeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to Playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _myPlaylists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No playlists created yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _myPlaylists.length,
                      itemBuilder: (context, index) {
                        final playlist = _myPlaylists[index];
                        // Check if this track is already in the playlist by its unique ID
                        final bool isAlreadyAdded = playlist.tracks.any((t) => t.id == track.id);

                        return ListTile(
                          enabled: !isAlreadyAdded,
                          leading: Icon(
                            Icons.playlist_add,
                            color: isAlreadyAdded
                                ? widget.activeTheme.textSecondary.withOpacity(0.5)
                                : widget.activeTheme.primaryAccent,
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
                          // Checkmark on the right side indicating presence
                          trailing: isAlreadyAdded
                              ? Icon(
                                  Icons.check_circle,
                                  color: widget.activeTheme.primaryAccent,
                                  size: 22,
                                )
                              : null,
                          onTap: isAlreadyAdded
                              ? null // Disables click functionality
                              : () {
                                  Navigator.pop(context);
                                  _addTrackToPlaylist(track, playlist);
                                },
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Create', style: TextStyle(color: widget.activeTheme.primaryAccent)),
              onPressed: () {
                _createNewPlaylist(nameController.text);
                Navigator.pop(context);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Playlist',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${_selectedPlaylistDetail?.name}"? This action cannot be undone.',
            style: TextStyle(color: widget.activeTheme.textSecondary),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                // Cancel Button Box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.activeTheme.searchBar,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: widget.activeTheme.textPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm Button Box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); // Close the dialog
                        setState(() {
                          _selectedForReorder.clear();
                          _isEditingOrder = false;
                          _myPlaylists.remove(_selectedPlaylistDetail);
                          _currentView = 'playlists';
                        });
                        await _playlistService.savePlaylists(_myPlaylists);
                      },
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  void _showThemeSelector(BuildContext context) {
    
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.activeTheme.surface,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Theme Palette', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.lens, color: Colors.deepPurpleAccent),
                title: const Text('Deep Purple'),
                onTap: () {
                  widget.onThemeChanged(AppColors.deepPurple);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lens, color: Colors.cyanAccent),
                title: const Text('Cyber Blue'),
                onTap: () {
                  widget.onThemeChanged(AppColors.cyberBlue);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lens, color: Colors.greenAccent),
                title: const Text('Forest Mint'),
                onTap: () {
                  widget.onThemeChanged(AppColors.forestMint);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
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
        return YoutubePlayerScaffold(
          controller: _playerController!,
          builder: (context, player) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return FutureBuilder<double>(
                  future: _playerController!.currentTime,
                  builder: (context, timeSnap) {
                    return FutureBuilder<Duration>(
                      future: _playerController!.duration,
                      builder: (context, durSnap) {
                        final currentSec = timeSnap.data ?? 0.0;
                        final duration = durSnap.data ?? Duration.zero;
                        final maxSec = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
                        final clampedSec = currentSec.clamp(0.0, maxSec);

                        return FractionallySizedBox(
                          heightFactor: 0.94,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              child: Column(
                                children: [
                                  // Drag Bar
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

                                  // Album Art
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
                                          _currentTrack!.thumbnailUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Title & Channel
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _currentTrack!.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _currentTrack!.channelTitle,
                                      style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 15),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Progress Slider
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
                                      value: clampedSec,
                                      min: 0.0,
                                      max: maxSec,
                                      onChanged: (val) {
                                        _playerController!.seekTo(seconds: val, allowSeekAhead: true);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),

                                  // Timers
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(Duration(seconds: clampedSec.toInt())),
                                          style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // Controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        iconSize: 36,
                                        icon: const Icon(Icons.skip_previous),
                                        onPressed: () {},
                                      ),
                                      CircleAvatar(
                                        radius: 34,
                                        backgroundColor: widget.activeTheme.primaryAccent,
                                        child: IconButton(
                                          iconSize: 34,
                                          color: widget.activeTheme.background,
                                          icon: const Icon(Icons.play_circle_fill),
                                          onPressed: () async {
                                            final state = await _playerController!.playerState;
                                            if (state == PlayerState.playing) {
                                              await _playerController!.pauseVideo();
                                            } else {
                                              await _playerController!.playVideo();
                                            }
                                            setModalState(() {});
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: 36,
                                        icon: const Icon(Icons.skip_next),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                  const Spacer(),

                                  // Player Element
                                  SizedBox(
                                    width: 1,
                                    height: 1,
                                    child: Opacity(
                                      opacity: 0.01,
                                      child: player,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
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

                  // === EDIT MODE ACTIVE: SHOW CONFIRM & CANCEL ===
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
                  ]

                  // === NORMAL MODE: SHOW EDIT, PLAY ALL, DELETE ===
                  else ...[
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
                          _playTrack(_selectedPlaylistDetail!.tracks.first);
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
                          // Only show the badges when in Edit Mode
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
                              : null,
                          onTap: () {
                            if (_isEditingOrder) {
                              // Reorder selection logic
                              setState(() {
                                if (isSelected) {
                                  _selectedForReorder.remove(track);
                                } else {
                                  _selectedForReorder.add(track);
                                }
                              });
                            } else {
                              // Normal playback mode
                              _playTrack(track);
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
                      icon: Icon(Icons.add_circle_outline, color: widget.activeTheme.primaryAccent),
                      onPressed: () => _showPlaylistSelector(track),
                    ),
                    onTap: () => _playTrack(track),
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
        child: Container(
          color: widget.activeTheme.surface,
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
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.activeTheme.searchBar,
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
                      // Changed 'padding' to the correct internal children padding parameter
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
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_currentTrack != null && _playerController != null)
            GestureDetector(
              onTap: _openFullPlayerScreen,
              child: Container(
                color: widget.activeTheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _currentTrack!.thumbnailUrl,
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
                            _currentTrack!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _currentTrack!.channelTitle,
                            style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    YoutubeValueBuilder(
                      controller: _playerController!,
                      builder: (context, value) {
                        final isPlaying = value.playerState == PlayerState.playing;
                        return IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (isPlaying) {
                              _playerController!.pauseVideo();
                            } else {
                              _playerController!.playVideo();
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}