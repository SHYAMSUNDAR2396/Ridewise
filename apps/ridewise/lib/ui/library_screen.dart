import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/capsule_store.dart';
import '../theme.dart';
import 'format.dart';
import 'navigation.dart';
import 'widgets/artwork.dart';
import 'widgets/generating_tag.dart';
import 'widgets/empty_state.dart';
import 'widgets/pill_chip.dart';

enum _Tab {
  recent('Recent', 'No capsules yet', 'Capsules you create will show up here.'),
  saved(
    'Saved',
    'No saved capsules',
    'Save a capsule from the player to find it here.',
  );

  const _Tab(this.label, this.emptyTitle, this.emptyMessage);
  final String label;
  final String emptyTitle;
  final String emptyMessage;
}

/// Library: Recent and Saved capsules as a flat list with artwork.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _Tab _tab = _Tab.recent;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<CapsuleStore>().capsules;
    final items = _tab == _Tab.saved
        ? [
            for (final c in all)
              if (c.saved) c,
          ]
        : all;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Library', style: displayStyle(38)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final t in _Tab.values) ...[
                PillChip(
                  label: t.label,
                  selected: _tab == t,
                  onPressed: () => setState(() => _tab = t),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            EmptyState(title: _tab.emptyTitle, message: _tab.emptyMessage)
          else
            for (final item in items) _Row(item: item),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final StoredCapsule item;

  @override
  Widget build(BuildContext context) {
    final c = item.capsule;
    final ratio = c.audioSeconds > 0
        ? item.progressSeconds / c.audioSeconds
        : 0.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: c.title,
              excludeSemantics: true,
              onTap: () => openPlayer(context, c),
              child: InkWell(
                onTap: () => openPlayer(context, c),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Artwork(seed: c.id, size: 52, radius: 9),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${c.topic}  ${formatMinutes(c.audioSeconds)}  ${c.language.code == 'en-IN' ? 'EN' : 'HI'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              GeneratingTag(capsuleId: c.id),
                              if (ratio > 0 && ratio < 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 3,
                                      backgroundColor: AppColors.line,
                                      color: AppColors.accent,
                                    ),
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
            ),
          ),
          IconButton(
            tooltip: 'Delete ${c.title}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            onPressed: () => context.read<CapsuleStore>().remove(c.id),
          ),
        ],
      ),
    );
  }
}
