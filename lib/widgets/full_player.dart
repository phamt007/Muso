import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme.dart';
import '../track_model.dart';

class FullPlayerModalContent extends StatelessWidget {
  final AudioPlayer player;
  final Track track;
  final AppColors activeTheme;
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
    required this.player,
    required this.track,
    required this.activeTheme,
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

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;

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
              Align(alignment: Alignment.centerLeft, child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: Text(track.channelTitle, style: TextStyle(color: activeTheme.textSecondary, fontSize: 15))),
              const SizedBox(height: 16),
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
              if (!isMobile) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(currentVolume == 0 ? Icons.volume_off : Icons.volume_down, color: activeTheme.textSecondary, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                            activeTrackColor: activeTheme.textPrimary,
                            inactiveTrackColor: activeTheme.searchBar,
                          ),
                          child: Slider(
                            value: currentVolume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: onVolumeChanged,
                          ),
                        ),
                      ),
                      Icon(Icons.volume_up, color: activeTheme.textSecondary, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(iconSize: 32, icon: const Icon(Icons.skip_previous), color: hasPlaylist ? Colors.white : Colors.grey.withOpacity(0.3), onPressed: onSkipPrevious),
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
                          color: hasPlaylist ? (isShuffling ? activeTheme.primaryAccent : Colors.grey) : Colors.grey.withOpacity(0.3),
                          onPressed: hasPlaylist ? () => onToggleShuffle(!isShuffling) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 28, color: Colors.grey),
                      onPressed: () {
                        if (onOptionsTap != null) onOptionsTap!();
                      },
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          iconSize: 24,
                          icon: const Icon(Icons.loop),
                          color: isLooping ? activeTheme.primaryAccent : Colors.grey,
                          onPressed: () => onToggleLoop(!isLooping),
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