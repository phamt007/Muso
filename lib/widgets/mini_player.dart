import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme.dart';
import '../track_model.dart';

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
                    child: track.thumbnailUrl.isNotEmpty
                        ? Image.network(track.thumbnailUrl, width: 50, height: 45, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 50, height: 45, decoration: BoxDecoration(color: activeTheme.primaryAccent.withOpacity(0.2)), child: Icon(Icons.music_note, color: activeTheme.primaryAccent)))
                        : Container(width: 50, height: 45, decoration: BoxDecoration(color: activeTheme.primaryAccent.withOpacity(0.2)), child: Icon(Icons.music_note, color: activeTheme.primaryAccent)),
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