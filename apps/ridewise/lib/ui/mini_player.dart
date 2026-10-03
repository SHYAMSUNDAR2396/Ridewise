import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/capsule_store.dart';
import '../data/now_playing.dart';
import '../playback/capsule_player.dart';
import '../theme.dart';
import 'format.dart';
import 'navigation.dart';
import 'widgets/artwork.dart';

/// Shows the capsule being played, with play/pause. Hidden until one is playing.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final stored = context.watch<CapsuleStore>().byId(
      context.watch<NowPlaying>().capsuleId,
    );
    if (stored == null) return const SizedBox.shrink();
    final playback = context.watch<CapsulePlayback>();
    final capsule = stored.capsule;
    final left = (capsule.audioSeconds - stored.progressSeconds).clamp(
      0,
      double.infinity,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      height: 60,
      padding: const EdgeInsets.only(left: 8, right: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Open player, ${capsule.title}',
              excludeSemantics: true,
              onTap: () => openPlayer(context, capsule),
              child: InkWell(
                onTap: () => openPlayer(context, capsule),
                child: Row(
                  children: [
                    Artwork(seed: capsule.id, size: 44, radius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            capsule.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${formatClock(left.toDouble())} left',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: playback.playing ? 'Pause' : 'Play',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
            onPressed: () =>
                playback.playing ? playback.pause() : playback.play(),
          ),
        ],
      ),
    );
  }
}
