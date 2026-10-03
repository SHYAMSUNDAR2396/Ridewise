import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/capsule_store.dart';
import '../data/now_playing.dart';
import '../domain/models.dart';
import '../playback/capsule_player.dart';
import '../theme.dart';
import 'format.dart';
import 'widgets/artwork.dart';
import 'widgets/retry_notice.dart';

/// Now Playing. No playback-speed control and no regenerate action: both are out of scope.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.capsule});

  final Capsule capsule;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragSeconds;

  @override
  void initState() {
    super.initState();
    // Stores notify listeners, which must not happen while the route is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final capsule = widget.capsule;
    final store = context.read<CapsuleStore>()..upsert(capsule);
    context.read<NowPlaying>().set(capsule.id);

    // Opening the player from the mini player must not restart a capsule that is already loaded.
    final playback = context.read<CapsulePlayback>();
    if (playback.capsule?.id == capsule.id && !playback.hasError) return;
    final progress = store.byId(capsule.id)?.progressSeconds ?? 0;
    playback.load(
      capsule,
      startSeconds: progress >= capsule.audioSeconds ? 0 : progress,
    );
  }

  void _showTranscript() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transcript',
                      style: displayStyle(26).copyWith(letterSpacing: 0),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Collapse transcript',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    widget.capsule.transcript,
                    style: const TextStyle(fontSize: 17, height: 1.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;
    final playback = context.watch<CapsulePlayback>();
    final saved =
        context.watch<CapsuleStore>().byId(capsule.id)?.saved ?? false;
    final loaded = playback.capsule?.id == capsule.id;
    final duration = capsule.audioSeconds;
    final position =
        _dragSeconds ??
        (loaded ? playback.positionSeconds.clamp(0, duration).toDouble() : 0.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.playerTop,
              AppColors.playerMid,
              AppColors.playerBottom,
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Semantics(
                button: true,
                label: 'Collapse player',
                excludeSemantics: true,
                onTap: () => Navigator.of(context).pop(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 120,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x73FFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Artwork(seed: capsule.id, size: 300, radius: 18),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capsule.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: displayStyle(
                          27,
                          color: AppColors.onPlayer,
                        ).copyWith(letterSpacing: -0.3),
                      ),
                      Text(
                        '${capsule.topic}, ${capsule.language.label}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPlayerMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (playback.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: RetryNotice(
                    headline: 'Audio unavailable right now.',
                    message:
                        "We couldn't load this capsule's audio. Try again.",
                    actionLabel: 'Retry',
                    onRetry: () =>
                        playback.load(capsule, startSeconds: position),
                  ),
                )
              else
                _Transport(
                  playback: playback,
                  position: position,
                  duration: duration,
                  onDrag: (v) => setState(() => _dragSeconds = v),
                  onDragEnd: (v) async {
                    await playback.seekTo(v);
                    if (mounted) setState(() => _dragSeconds = null);
                  },
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Action(
                      icon: Icons.notes_rounded,
                      label: 'Transcript',
                      onTap: _showTranscript,
                    ),
                    _Action(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: saved ? 'Saved' : 'Save',
                      onTap: () =>
                          context.read<CapsuleStore>().toggleSaved(capsule.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.playback,
    required this.position,
    required this.duration,
    required this.onDrag,
    required this.onDragEnd,
  });

  final CapsulePlayback playback;
  final double position;
  final double duration;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.onPlayer,
              inactiveTrackColor: AppColors.onPlayerFaint,
              thumbColor: AppColors.onPlayer,
              overlayColor: AppColors.onPlayerFaint,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: position.clamp(0, duration <= 0 ? 1 : duration).toDouble(),
              max: duration <= 0 ? 1 : duration,
              onChanged: onDrag,
              onChangeEnd: onDragEnd,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatClock(position),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPlayerMuted,
                ),
              ),
              Text(
                '-${formatClock(duration - position)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPlayerMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Replay 10 seconds',
              iconSize: 36,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              color: AppColors.onPlayer,
              onPressed: () => playback.seekBy(-10),
              icon: const Icon(Icons.replay_10_rounded),
            ),
            const SizedBox(width: 24),
            IconButton.filled(
              tooltip: playback.playing ? 'Pause' : 'Play',
              iconSize: 36,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.onPlayer,
                foregroundColor: AppColors.playerMid,
                fixedSize: const Size(76, 76),
              ),
              onPressed: () =>
                  playback.playing ? playback.pause() : playback.play(),
              icon: Icon(
                playback.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              tooltip: 'Forward 30 seconds',
              iconSize: 36,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              color: AppColors.onPlayer,
              onPressed: () => playback.seekBy(30),
              icon: const Icon(Icons.forward_30_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.onPlayer),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onPlayer,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
