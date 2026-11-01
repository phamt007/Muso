import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme.dart';
import '../track_model.dart';

class FullPlayerModalContent extends StatelessWidget {
  final AudioPlayer player;
  final AppColors activeTheme;
  final ValueListenable<Track?> trackListenable;
  final ValueListenable<bool> hasPlaylistListenable;
  final ValueListenable<bool> canSkipNextListenable;
  final ValueListenable<bool> loopListenable;
  final ValueListenable<bool> shuffleListenable;
  final ValueListenable<double> volumeListenable;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool> onToggleLoop;
  final ValueChanged<bool> onToggleShuffle;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onOptionsTap;

  const FullPlayerModalContent({
    super.key,
    required this.player,
    required this.activeTheme,
    required this.trackListenable,
    required this.hasPlaylistListenable,
    required this.canSkipNextListenable,
    required this.loopListenable,
    required this.shuffleListenable,
    required this.volumeListenable,
    required this.onVolumeChanged,
    required this.onToggleLoop,
    required this.onToggleShuffle,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

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

              ValueListenableBuilder<Track?>(
                valueListenable: trackListenable,
                builder: (context, track, _) {
                  if (track == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(track.channelTitle, style: TextStyle(color: activeTheme.textSecondary, fontSize: 15)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              SeekBar(player: player, activeTheme: activeTheme),
              const Spacer(),

              if (!isMobile) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder<double>(
                    valueListenable: volumeListenable,
                    builder: (context, volume, _) {
                      return Row(
                        children: [
                          Icon(volume == 0 ? Icons.volume_off : Icons.volume_down, color: activeTheme.textSecondary, size: 20),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                activeTrackColor: activeTheme.textPrimary,
                                inactiveTrackColor: activeTheme.searchBar,
                              ),
                              child: Slider(value: volume, min: 0.0, max: 1.0, onChanged: onVolumeChanged),
                            ),
                          ),
                          Icon(Icons.volume_up, color: activeTheme.textSecondary, size: 20),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: hasPlaylistListenable,
                    builder: (context, hasPlaylist, _) => IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.skip_previous),
                      color: hasPlaylist ? Colors.white : Colors.grey.withOpacity(0.3),
                      onPressed: hasPlaylist ? onSkipPrevious : null,
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final playing = state?.playing ?? false;
                      final loading = state?.processingState == ProcessingState.loading ||
                          state?.processingState == ProcessingState.buffering;
                      return CircleAvatar(
                        radius: 32,
                        backgroundColor: activeTheme.primaryAccent,
                        child: loading
                            ? SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 3, color: activeTheme.background),
                              )
                            : IconButton(
                                iconSize: 32,
                                color: activeTheme.background,
                                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                                onPressed: () => playing ? player.pause() : player.play(),
                              ),
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: canSkipNextListenable,
                    builder: (context, canSkip, _) => IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.skip_next),
                      color: canSkip ? Colors.white : Colors.grey.withOpacity(0.3),
                      onPressed: canSkip ? onSkipNext : null,
                    ),
                  ),
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
                        child: ListenableBuilder(
                          listenable: Listenable.merge([hasPlaylistListenable, shuffleListenable]),
                          builder: (context, _) {
                            final hasPlaylist = hasPlaylistListenable.value;
                            final isShuffling = shuffleListenable.value;
                            return IconButton(
                              iconSize: 24,
                              icon: const Icon(Icons.shuffle),
                              color: hasPlaylist ? (isShuffling ? activeTheme.primaryAccent : Colors.grey) : Colors.grey.withOpacity(0.3),
                              onPressed: hasPlaylist ? () => onToggleShuffle(!isShuffling) : null,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 28, color: Colors.grey),
                      onPressed: onOptionsTap,
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: loopListenable,
                          builder: (context, isLooping, _) => IconButton(
                            iconSize: 24,
                            icon: const Icon(Icons.loop),
                            color: isLooping ? activeTheme.primaryAccent : Colors.grey,
                            onPressed: () => onToggleLoop(!isLooping),
                          ),
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

class SeekBar extends StatefulWidget {
  final AudioPlayer player;
  final AppColors activeTheme;

  const SeekBar({super.key, required this.player, required this.activeTheme});

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragMs;

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.activeTheme;
    return StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      initialData: widget.player.duration,
      builder: (context, durSnap) {
        final duration = durSnap.data ?? Duration.zero;
        final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;

        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final valueMs = (_dragMs ?? position.inMilliseconds.toDouble()).clamp(0.0, maxMs);

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    activeTrackColor: theme.primaryAccent,
                    inactiveTrackColor: theme.searchBar,
                    thumbColor: theme.primaryAccent,
                  ),
                  child: Slider(
                    value: valueMs,
                    min: 0.0,
                    max: maxMs,
                    onChanged: (v) => setState(() => _dragMs = v),
                    onChangeEnd: (v) {
                      widget.player.seek(Duration(milliseconds: v.toInt()));
                      setState(() => _dragMs = null);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(Duration(milliseconds: valueMs.toInt())), style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      Text(_fmt(duration), style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}