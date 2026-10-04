import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/trip_store.dart';
import '../domain/models.dart';
import '../generation/types.dart';
import '../theme.dart';
import 'navigation.dart';
import 'widgets/pill_chip.dart';
import 'widgets/primary_button.dart';
import 'widgets/retry_notice.dart';

const _suggestions = [
  'India and the world',
  'Careers',
  'Personal finance',
  'Technology',
  'History',
  'Language',
];

const _styleBlurb = {
  ListeningStyle.quickOverview: 'Key highlights. Best for short rides.',
  ListeningStyle.learnDeeply: 'In-depth context. Ideal for longer rides.',
};

String progressLabel(GenerationProgress? p) => switch (p?.phase) {
  GenerationPhase.models => 'Getting ready, ${p!.done}%',
  GenerationPhase.script => 'Writing your script...',
  GenerationPhase.voice => 'Recording part ${p!.done + 1} of ${p.total}...',
  null => 'Preparing your capsule...',
};

enum _Status { idle, loading, error }

/// Topic, style and language, then generate the capsule on the phone.
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _custom = TextEditingController();
  String? _chip;
  ListeningStyle _style = ListeningStyle.quickOverview;
  CapsuleLanguage _language = CapsuleLanguage.enIN;
  _Status _status = _Status.idle;
  GenerationProgress? _progress;
  String? _errorMessage;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _topic =>
      _custom.text.trim().isNotEmpty ? _custom.text.trim() : (_chip ?? '');

  bool _canGenerate(TripDraft draft) =>
      _topic.isNotEmpty &&
      (draft.tripSeconds ?? 0) > 0 &&
      _status != _Status.loading;

  Future<void> _generate() async {
    final draft = context.read<TripStore>().draft;
    if (!_canGenerate(draft)) return;
    final generate = context.read<GenerateCapsule>();
    setState(() {
      _status = _Status.loading;
      _progress = null;
    });
    try {
      final capsule = await generate(
        CreateCapsuleRequest(
          trip: draft,
          topic: _topic,
          style: _style,
          language: _language,
        ),
        (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _status = _Status.idle);
      await openPlayer(context, capsule);
    } catch (e) {
      // Topic, style, language and trip selections stay as they are so Retry resubmits the same request.
      if (mounted) {
        setState(() {
          _status = _Status.error;
          _errorMessage = e is GenerationException ? e.message : null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<TripStore>().draft;
    final generating = _status == _Status.loading;
    return PopScope(
      canPop: !generating,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !generating,
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Text(
                        'What should we cover?',
                        style: displayStyle(38).copyWith(height: 1.1),
                      ),
                      const SizedBox(height: 18),
                      if (_status == _Status.error) ...[
                        const SizedBox(height: 0),
                        RetryNotice(
                          headline: 'Your capsule needs another moment.',
                          message:
                              _errorMessage ??
                              'Something went wrong, and your selections are saved. Try again.',
                          actionLabel: 'Retry',
                          onRetry: _generate,
                        ),
                      ],
                      if (_status == _Status.error) const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _suggestions)
                            PillChip(
                              label: s,
                              selected:
                                  _chip == s && _custom.text.trim().isEmpty,
                              onPressed: () => setState(() {
                                _chip = s;
                                _custom.clear();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('custom-topic'),
                        controller: _custom,
                        onChanged: (text) => setState(() {
                          if (text.trim().isNotEmpty) _chip = null;
                        }),
                        decoration: InputDecoration(
                          hintText: 'Or type your own topic',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCDEE4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Label('LISTENING STYLE'),
                      Row(
                        children: [
                          for (final s in ListeningStyle.values) ...[
                            if (s != ListeningStyle.values.first)
                              const SizedBox(width: 12),
                            Expanded(
                              child: _StyleCard(
                                style: s,
                                blurb: _styleBlurb[s]!,
                                selected: _style == s,
                                onTap: () => setState(() => _style = s),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _Label('LANGUAGE'),
                      Container(
                        height: 52,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            for (final l in CapsuleLanguage.values)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: _language == l,
                                  label: l.label,
                                  excludeSemantics: true,
                                  onTap: () => setState(() => _language = l),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => setState(() => _language = l),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _language == l
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: _language == l
                                            ? const [
                                                BoxShadow(
                                                  color: Color(0x24000000),
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        l.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: _language == l
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                          color: _language == l
                                              ? AppColors.text
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: PrimaryButton(
                      label: 'Generate my capsule',
                      onPressed: _canGenerate(draft) ? _generate : null,
                    ),
                  ),
                ),
              ],
            ),
            if (_status == _Status.loading)
              _LoadingOverlay(progress: _progress),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });
  final ListeningStyle style;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                style.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blurb,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF434A58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.progress});
  final GenerationProgress? progress;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.playerTop, AppColors.playerBottom],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.onPlayer),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                progressLabel(progress),
                textAlign: TextAlign.center,
                style: displayStyle(
                  24,
                  color: AppColors.onPlayer,
                ).copyWith(letterSpacing: 0),
              ),
            ),
            if (progress?.phase == GenerationPhase.models) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Downloading the voice and writer once. They stay on this phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onPlayerMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
