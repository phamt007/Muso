
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
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
  final List<Track> _selectedForReorder = [];
  
  List<Track> _searchResults = [];
  List<Playlist> _myPlaylists = [];
  Track? _currentTrack;
  YoutubePlayerController? _playerController;

  String _currentView = 'search'; 
  Playlist? _selectedPlaylistDetail;

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
      if (_playerController != null) {
        _playerController!.load(track.id);
      } else {
        _playerController = YoutubePlayerController(
          initialVideoId: track.id,
          flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
        );
      }
    });
  }

  void _showPlaylistSelector(Track track) {
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
              const Text('Add to Playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _myPlaylists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No playlists created yet.', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _myPlaylists.length,
                      itemBuilder: (context, index) {
                        final playlist = _myPlaylists[index];
                        return ListTile(
                          leading: Icon(Icons.playlist_add, color: widget.activeTheme.primaryAccent),
                          title: Text(playlist.name),
                          onTap: () {
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
                        _selectedForReorder.clear();
                        _currentView = 'playlists';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPlaylistDetail!.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: widget.activeTheme.primaryAccent, size: 28),
                    tooltip: 'Edit Playlist Order',
                    onPressed: () async {
                      if (_selectedForReorder.isEmpty) return;

                      setState(() {
                        // Create a list for unselected tracks
                        final unselected = _selectedPlaylistDetail!.tracks
                            .where((t) => !_selectedForReorder.contains(t))
                            .toList();

                        // Place selected tracks first in order of selection, then append remaining tracks
                        _selectedPlaylistDetail!.tracks.clear();
                        _selectedPlaylistDetail!.tracks.addAll(_selectedForReorder);
                        _selectedPlaylistDetail!.tracks.addAll(unselected);

                        _selectedForReorder.clear();
                      });

                      await _playlistService.savePlaylists(_myPlaylists);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Playlist order updated!')),
                        );
                      }
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
                    onPressed: () async {
                      setState(() {
                        _selectedForReorder.clear();
                        _myPlaylists.remove(_selectedPlaylistDetail);
                        _currentView = 'playlists';
                      });
                      await _playlistService.savePlaylists(_myPlaylists);
                    },
                  ),
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
                          trailing: isSelected
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
                              : const Icon(Icons.circle_outlined, color: Colors.grey),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedForReorder.remove(track);
                              } else {
                                _selectedForReorder.add(track);
                              }
                            });
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
              
// === INLINE EXPANDABLE THEME SELECTION BOX ===
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
            Container(
              color: widget.activeTheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 45,
                    child: YoutubePlayer(
                      controller: _playerController!,
                      showVideoProgressIndicator: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currentTrack!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_currentTrack!.channelTitle, style: TextStyle(color: widget.activeTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: () => _playerController!.pause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playerController!.play(),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}