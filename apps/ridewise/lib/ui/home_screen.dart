import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/capsule_store.dart';
import '../data/trip_store.dart';
import '../domain/models.dart';
import '../theme.dart';
import 'format.dart';
import 'navigation.dart';
import 'shell.dart';
import 'widgets/artwork.dart';
import 'widgets/generating_tag.dart';
import 'widgets/empty_state.dart';

/// Listen Now: the next ride, what was made recently, and what is still in progress.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<TripStore>().draft;
    final capsules = context.watch<CapsuleStore>().capsules;
    final hasTrip =
        (draft.startLabel ?? '').isNotEmpty &&
        (draft.endLabel ?? '').isNotEmpty;
    final inProgress = [
      for (final c in capsules)
        if (c.progressSeconds > 0 && c.progressSeconds < c.capsule.audioSeconds)
          c,
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Listen Now', style: displayStyle(38)),
          const SizedBox(height: 14),
          _Hero(hasTrip: hasTrip, draft: draft),
          const SizedBox(height: 22),
          const _SectionTitle('Recently made'),
          if (capsules.isEmpty)
            const EmptyState(
              title: 'No capsules yet',
              message: 'Plan a ride and your first capsule will show up here.',
            )
          else
            SizedBox(
              height: 148 + 8 + 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: capsules.length > 8 ? 8 : capsules.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final c = capsules[i].capsule;
                  return Semantics(
                    button: true,
                    label: c.title,
                    excludeSemantics: true,
                    onTap: () => openPlayer(context, c),
                    child: InkWell(
                      onTap: () => openPlayer(context, c),
                      child: SizedBox(
                        width: 148,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Artwork(seed: c.id, size: 148, radius: 14),
                            const SizedBox(height: 8),
                            Text(
                              c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${c.language.label}, ${formatMinutes(c.audioSeconds)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            GeneratingTag(capsuleId: c.id),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (inProgress.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionTitle('Continue listening'),
            for (final s in inProgress.take(3))
              Semantics(
                button: true,
                label: 'Continue ${s.capsule.title}',
                excludeSemantics: true,
                onTap: () => openPlayer(context, s.capsule),
                child: InkWell(
                  onTap: () => openPlayer(context, s.capsule),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Row(
                      children: [
                        Artwork(seed: s.id, size: 48, radius: 9),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.capsule.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${s.capsule.topic}, ${formatMinutes(s.capsule.audioSeconds - s.progressSeconds)} left',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              GeneratingTag(capsuleId: s.id),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.hasTrip, required this.draft});
  final bool hasTrip;
  final TripDraft draft;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Plan a capsule',
      excludeSemantics: true,
      onTap: () => context.read<ShellController>().goTo(ShellController.plan),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              context.read<ShellController>().goTo(ShellController.plan),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.playerMid],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasTrip ? 'NEXT RIDE' : 'NEW RIDE',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTrip
                      ? '${draft.startLabel} to ${draft.endLabel}'
                      : 'Where are you headed?',
                  style: displayStyle(
                    27,
                    color: AppColors.onAccent,
                  ).copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTrip && draft.transportMode != null
                      ? draft.transportMode!.label
                      : 'We will time a capsule to your trip.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: AppColors.accentInk,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Plan a capsule',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentInk,
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
    );
  }
}
