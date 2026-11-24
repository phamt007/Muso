import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'storage_service.dart';
import 'dart:async';

import 'theme.dart';
import 'widgets/mini_player.dart';
import 'widgets/full_player.dart';
import 'youtube_service.dart';
import 'track_model.dart';
import 'playlist_model.dart';
import 'widgets/infinite_list.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tap007.rhythic.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

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

  final AudioPlayer _audioPlayer = AudioPlayer();

  YoutubeExplode _ytExplode = YoutubeExplode();
  int _playRequestId = 0;
  int _consecutiveFailures = 0;
  String? _preloadAttemptedFor;
  StreamSubscription? _stateSub;
  ConcatenatingAudioSource? _concat;
  Track? _appendedNext;
  Track? _shuffleNext;
  StreamSubscription? _indexSub;

  final StorageService _storage = StorageService();

  StreamSubscription? _positionSubscription;

  List<Track> _searchResults = [];
  String _currentView = 'search';

  Playlist? _selectedPlaylistDetail;
  final List<Playlist> _myPlaylists = [];

  bool _isEditingOrder = false;
  final List<Track> _selectedForReorder = [];

  Track? _preloadedNextTrack;
  String? _preloadedNextUrl;
  DateTime? _lastPrevTap;
  final List<Track> _history = [];

  Track? _currentTrack;
  Playlist? _activePlaylist;
  Track? _playlistAnchor;
  final List<Track> _queue = [];

  final ValueNotifier<Track?> _trackNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _loopNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _shuffleNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _hasPlaylistNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _canSkipNextNotifier = ValueNotifier(false);
  final ValueNotifier<double> _volumeNotifier = ValueNotifier(1.0);

  bool get _isShuffling => _shuffleNotifier.value;

  void _syncNav() {
    _hasPlaylistNotifier.value = _activePlaylist != null;
    _canSkipNextNotifier.value = _activePlaylist != null || _queue.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _initAudioSession();

    _storage.loadPlaylists().then((savedData) {
      if (mounted) {
        setState(() => _myPlaylists.addAll(savedData));
      }
    });

    _stateSub = _audioPlayer.processingStateStream
        .distinct()
        .listen((s) {
      debugPrint('STATE: $s');
      if (s == ProcessingState.completed) _playNextTrack();
    });

    _audioPlayer.playbackEventStream.listen(
      (_) {},
      onError: (e, st) => debugPrint('PLAYER ERROR: $e'),
    );

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      final duration = _audioPlayer.duration;
      final current = _currentTrack;
      if (duration == null || current == null || position == Duration.zero) return;
      if (duration.inSeconds - position.inSeconds <= 30 &&
          _preloadAttemptedFor != current.id) {
        _preloadNextTrack();
      }
    });

    _indexSub = _audioPlayer.currentIndexStream.listen((index) {
      final next = _appendedNext;
      if (index == null || index == 0 || next == null) return;
      _appendedNext = null;
      _shuffleNext = null;
      _preloadedNextTrack = null;
      _preloadedNextUrl = null;

      _pushHistory();
      setState(() {
        _currentTrack = next;
        if (_queue.isNotEmpty && _queue.first.id == next.id) {
          _queue.removeAt(0);
        } else if (_activePlaylist != null) {
          _playlistAnchor = next;
        }
      });
      _trackNotifier.value = next;
      _syncNav();

      _concat?.removeRange(0, index);
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSub?.cancel();
    _indexSub?.cancel();
    _ytExplode.close();
    _audioPlayer.dispose();
    _trackNotifier.dispose();
    _loopNotifier.dispose();
    _shuffleNotifier.dispose();
    _hasPlaylistNotifier.dispose();
    _canSkipNextNotifier.dispose();
    _volumeNotifier.dispose();
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

  Future<String> _resolveUrl(Track track) async {
    final manifest = await _ytExplode.videos.streamsClient
        .getManifest(track.id)
        .timeout(const Duration(seconds: 15));
    final streams = manifest.muxed.where((s) => s.container.name == 'mp4');
    if (streams.isEmpty) throw Exception('No compatible stream');
    return streams
        .reduce((a, b) => a.bitrate.bitsPerSecond <= b.bitrate.bitsPerSecond ? a : b)
        .url
        .toString();
  }

  AudioSource _buildSource(Track track, String url) {
    return AudioSource.uri(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      },
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.channelTitle,
        artUri: track.thumbnailUrl.isNotEmpty ? Uri.parse(track.thumbnailUrl) : null,
      ),
    );
  }

  Track? _computeNextTrack() {
    if (_queue.isNotEmpty) return _queue.first;
    if (_activePlaylist == null || _playlistAnchor == null) return null;
    final tracks = _activePlaylist!.tracks;
    if (tracks.isEmpty) return null;

    if (_isShuffling) {
      if (_shuffleNext == null) {
        final pool = tracks.length > 1
            ? tracks.where((t) => t.id != _playlistAnchor!.id).toList()
            : tracks;
        _shuffleNext = pool[Random().nextInt(pool.length)];
      }
      return _shuffleNext;
    }

    final i = tracks.indexWhere((t) => t.id == _playlistAnchor!.id);
    if (i != -1 && i < tracks.length - 1) return tracks[i + 1];
    return tracks.first;
  }

  void _invalidateAppended() {
    final concat = _concat;
    if (concat != null && _appendedNext != null && concat.length > 1) {
      concat.removeAt(1);
    }
    _appendedNext = null;
    _preloadedNextTrack = null;
    _preloadedNextUrl = null;
    _preloadAttemptedFor = null;
  }

  void _toggleShuffle(bool value) {
    _shuffleNotifier.value = value;
    _shuffleNext = null;
    if (!value) _history.clear();
    _invalidateAppended();
  }

  void _pushHistory() {
    final current = _currentTrack;
    if (!_isShuffling || current == null) return;
    if (_history.isNotEmpty && _history.last.id == current.id) return;
    _history.add(current);
    if (_history.length > 50) _history.removeAt(0);
  }

  Future<void> _preloadNextTrack() async {
    final current = _currentTrack;
    final concat = _concat;
    if (current == null || concat == null) return;
    _preloadAttemptedFor = current.id;

    final nextTrack = _computeNextTrack();
    if (nextTrack == null) return;

    try {
      final url = await _resolveUrl(nextTrack);
      if (_currentTrack?.id != current.id ||
          _concat != concat ||
          _appendedNext != null) {
        return;
      }
      if (_computeNextTrack()?.id != nextTrack.id) return;
      _preloadedNextTrack = nextTrack;
      _preloadedNextUrl = url;
      _appendedNext = nextTrack;
      await concat.add(_buildSource(nextTrack, url));
    } catch (e) {
      debugPrint('Preload failed: $e');
    }
  }

  void _playNextTrack() {
    final next = _computeNextTrack();
    if (next == null) return;
    _pushHistory();
    if (_queue.isNotEmpty && _queue.first.id == next.id) {
      _queue.removeAt(0);
      _playTrack(next, showScreen: false, isFromQueue: true, isNavigation: true);
    } else {
      _playTrack(next, playlist: _activePlaylist, showScreen: false, isNavigation: true);
    }
  }

  Track? _computePreviousTrack() {
    if (_activePlaylist == null || _playlistAnchor == null) return null;
    if (_isShuffling) return _history.isNotEmpty ? _history.last : null;
    final tracks = _activePlaylist!.tracks;
    final i = tracks.indexWhere((t) => t.id == _playlistAnchor!.id);
    return i > 0 ? tracks[i - 1] : null;
  }

  void _playPreviousTrack() {
    final now = DateTime.now();
    final last = _lastPrevTap;
    _lastPrevTap = now;

    final tappedTwice =
        last != null && now.difference(last) < const Duration(seconds: 1);
    final nearStart = _audioPlayer.position < const Duration(seconds: 1);
    final prev = _computePreviousTrack();

    if ((tappedTwice || nearStart) && prev != null) {
      _lastPrevTap = null;
      if (_isShuffling && _history.isNotEmpty) _history.removeLast();
      _playTrack(prev, playlist: _activePlaylist, showScreen: false, isNavigation: true);
      return;
    }

    _audioPlayer.seek(Duration.zero);
  }

  Future<void> _playTrack(Track track,
      {Playlist? playlist,
      bool showScreen = true,
      bool isFromQueue = false,
      bool retried = false,
      bool isNavigation = false}) async {
    final myId = ++_playRequestId;
    if (!isNavigation) _history.clear();
    _shuffleNext = null;
    _appendedNext = null;

    setState(() {
      _currentTrack = track;
      if (!isFromQueue) {
        _activePlaylist = playlist;
        _queue.clear();
        _playlistAnchor = playlist != null ? track : null;
      }
    });
    _trackNotifier.value = track;
    _syncNav();

    try {
      final String audioUrl;
      if (_preloadedNextTrack?.id == track.id && _preloadedNextUrl != null) {
        audioUrl = _preloadedNextUrl!;
      } else {
        _showDebugNotification('Extracting manifest...');
        audioUrl = await _resolveUrl(track);
      }
      if (myId != _playRequestId) return;

      _preloadedNextTrack = null;
      _preloadedNextUrl = null;

      final concat = ConcatenatingAudioSource(children: [_buildSource(track, audioUrl)]);
      _concat = concat;
      await _audioPlayer.setAudioSource(concat);
      if (myId != _playRequestId) return;

      _audioPlayer.play();
      _consecutiveFailures = 0;
      if (showScreen) _openFullPlayerScreen();
    } catch (e) {
      debugPrint('Play failed for "${track.title}": $e');
      if (myId != _playRequestId) return;

      _preloadedNextTrack = null;
      _preloadedNextUrl = null;

      if (!retried) {
        _ytExplode.close();
        _ytExplode = YoutubeExplode();
        return _playTrack(track,
            playlist: playlist,
            showScreen: showScreen,
            isFromQueue: isFromQueue,
            retried: true,
            isNavigation: isNavigation);
      }

      if (!showScreen && ++_consecutiveFailures <= 3) {
        _showDebugNotification('Skipping "${track.title}"');
        _playNextTrack();
      } else {
        _showDebugNotification('Could not play "${track.title}"');
      }
    }
  }

  void _createNewPlaylist(String name, {Track? initialTrack}) {
    if (name.isEmpty) return;
    final newPlaylist = Playlist(
      name: name,
      tracks: initialTrack != null ? [initialTrack] : [],
    );
    setState(() {
      _myPlaylists.add(newPlaylist);
    });

    _storage.savePlaylists(_myPlaylists);

    if (initialTrack != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to ${newPlaylist.name}')),
      );
    }
  }

  void _addTrackToPlaylist(Track track, Playlist playlist) {
    setState(() {
      playlist.tracks.add(track);
    });

    _storage.savePlaylists(_myPlaylists);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to ${playlist.name}')),
    );
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
      _showDebugNotification('Found ${results.length} results!');
    } catch (e) {
      _showDebugNotification('ERROR: $e');
    }
  }

  void _showTrackMenu(Track track, {Playlist? fromPlaylist}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.activeTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Track Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(Icons.queue_music, color: widget.activeTheme.primaryAccent),
                title: Text('Add to Queue', style: TextStyle(color: widget.activeTheme.primaryAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  setState(() => _queue.add(track));
                  _invalidateAppended();
                  _syncNav();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Queue to play next')));
                },
              ),

              if (fromPlaylist != null && fromPlaylist.tracks.any((t) => t.id == track.id)) ...[
                ListTile(
                  leading: Icon(Icons.delete, color: widget.activeTheme.primaryAccent),
                  title: Text('Delete Track from Playlist', style: TextStyle(color: widget.activeTheme.primaryAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    setState(() => fromPlaylist.tracks.removeWhere((t) => t.id == track.id));
                    if (identical(fromPlaylist, _activePlaylist)) _invalidateAppended();
                    _storage.savePlaylists(_myPlaylists);
                    _syncNav();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track deleted from playlist')));
                  },
                ),
              ],
              const Divider(color: Colors.grey),
              ListTile(
                leading: Icon(Icons.add_box, color: widget.activeTheme.textPrimary),
                title: Text('Create New Playlist', style: TextStyle(color: widget.activeTheme.textPrimary, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showCreatePlaylistDialog(context, trackToAdd: track);
                },
              ),
              const Divider(color: Colors.grey),
              _myPlaylists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No existing playlists.', style: TextStyle(color: Colors.grey))),
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
                              color: isAlreadyAdded ? widget.activeTheme.textSecondary.withOpacity(0.5) : widget.activeTheme.textPrimary,
                            ),
                            title: Text(
                              playlist.name,
                              style: TextStyle(color: isAlreadyAdded ? widget.activeTheme.textSecondary : widget.activeTheme.textPrimary),
                            ),
                            subtitle: isAlreadyAdded ? const Text('Already in playlist', style: TextStyle(fontSize: 12, color: Colors.grey)) : null,
                            trailing: isAlreadyAdded ? Icon(Icons.check_circle, color: widget.activeTheme.primaryAccent, size: 22) : null,
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
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.activeTheme.primaryAccent)),
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
                    decoration: BoxDecoration(color: widget.activeTheme.searchBar, borderRadius: BorderRadius.circular(8)),
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
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        setState(() {
                          _selectedForReorder.clear();
                          _isEditingOrder = false;
                          _myPlaylists.remove(_selectedPlaylistDetail);
                          _storage.savePlaylists(_myPlaylists);
                          _currentView = 'playlists';
                        });
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
    if (_currentTrack == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: widget.activeTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return FullPlayerModalContent(
          player: _audioPlayer,
          activeTheme: widget.activeTheme,
          trackListenable: _trackNotifier,
          hasPlaylistListenable: _hasPlaylistNotifier,
          canSkipNextListenable: _canSkipNextNotifier,
          loopListenable: _loopNotifier,
          shuffleListenable: _shuffleNotifier,
          volumeListenable: _volumeNotifier,
          onVolumeChanged: (val) {
            _volumeNotifier.value = val;
            _audioPlayer.setVolume(val);
          },
          onToggleLoop: (val) {
            _loopNotifier.value = val;
            _audioPlayer.setLoopMode(val ? LoopMode.one : LoopMode.off);
          },
          onToggleShuffle: _toggleShuffle,
          onSkipNext: _playNextTrack,
          onSkipPrevious: _playPreviousTrack,
          onOptionsTap: () {
            final t = _trackNotifier.value;
            if (t != null) _showTrackMenu(t);
          },
        );
      },
    );
  }

  Widget _buildBody() {
    final Widget fallbackThumbnail = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(color: widget.activeTheme.primaryAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.music_note, color: widget.activeTheme.primaryAccent),
    );

    switch (_currentView) {
      case 'playlists':
        return InfiniteList(
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

        Widget buildTrackTile(BuildContext context, int index) {
          final track = _selectedPlaylistDetail!.tracks[index];
          final isSelected = _selectedForReorder.contains(track);
          final selectIndex = _selectedForReorder.indexOf(track) + 1;

          return ListTile(
            leading: track.thumbnailUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(track.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallbackThumbnail),
                  )
                : fallbackThumbnail,
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(track.channelTitle),
            trailing: _isEditingOrder
                ? (isSelected
                    ? CircleAvatar(
                        radius: 14,
                        backgroundColor: widget.activeTheme.primaryAccent,
                        child: Text('$selectIndex', style: TextStyle(color: widget.activeTheme.surface, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    : const Icon(Icons.circle_outlined, color: Colors.grey))
                : IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showTrackMenu(track, fromPlaylist: _selectedPlaylistDetail)),
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
        }

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
                      onPressed: () => setState(() {
                        _selectedForReorder.clear();
                        _isEditingOrder = false;
                      }),
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: widget.activeTheme.primaryAccent, size: 28),
                      onPressed: () {
                        if (_selectedForReorder.isNotEmpty) {
                          setState(() {
                            final unselected = _selectedPlaylistDetail!.tracks.where((t) => !_selectedForReorder.contains(t)).toList();
                            _selectedPlaylistDetail!.tracks.clear();
                            _selectedPlaylistDetail!.tracks.addAll(_selectedForReorder);
                            _selectedPlaylistDetail!.tracks.addAll(unselected);
                            _storage.savePlaylists(_myPlaylists);
                            _invalidateAppended();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playlist order updated!')));
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
                      onPressed: () => setState(() {
                        _selectedForReorder.clear();
                        _isEditingOrder = true;
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _showDeletePlaylistDialog(context),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _selectedPlaylistDetail!.tracks.isEmpty
                  ? const Center(child: Text('This playlist is empty.', style: TextStyle(color: Colors.grey)))
                  : _isEditingOrder
                      ? ListView.builder(
                          itemCount: _selectedPlaylistDetail!.tracks.length,
                          itemBuilder: buildTrackTile,
                        )
                      : InfiniteList(
                          itemCount: _selectedPlaylistDetail!.tracks.length,
                          itemBuilder: buildTrackTile,
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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: widget.activeTheme.searchBar,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
                onSubmitted: _executeSearch,
              ),
            ),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(child: Icon(Icons.search, size: 80, color: widget.activeTheme.primaryAccent.withOpacity(0.5)))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final track = _searchResults[index];
                        return ListTile(
                          leading: track.thumbnailUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(track.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallbackThumbnail),
                                )
                              : fallbackThumbnail,
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
              decoration: BoxDecoration(color: widget.activeTheme.searchBar),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 40, color: widget.activeTheme.primaryAccent),
                  const SizedBox(height: 10),
                  const Text('Muso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: widget.activeTheme.textPrimary),
              title: const Text('Home / Search'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentView = 'search');
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_play, color: widget.activeTheme.textPrimary),
              title: const Text('My Playlists'),
              subtitle: Text('${_myPlaylists.length} playlists created', style: TextStyle(color: widget.activeTheme.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentView = 'playlists');
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
                      title: Text('Active Theme Layout', style: TextStyle(color: widget.activeTheme.textPrimary, fontSize: 16)),
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
