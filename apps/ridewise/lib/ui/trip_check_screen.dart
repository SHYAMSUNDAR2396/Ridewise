import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../data/trip_store.dart';
import '../domain/models.dart';
import '../theme.dart';
import 'duration_stepper.dart';
import 'topic_screen.dart';
import 'widgets/primary_button.dart';
import 'widgets/retry_notice.dart';

enum _Status { loading, success, failure }

/// Confirms the trip time: the route estimate, editable, or a manual time when routing fails.
class TripCheckScreen extends StatefulWidget {
  const TripCheckScreen({super.key});

  @override
  State<TripCheckScreen> createState() => _TripCheckScreenState();
}

class _TripCheckScreenState extends State<TripCheckScreen> {
  _Status _status = _Status.loading;
  RouteEstimate? _estimate;
  bool _editing = false;
  int? _editedMinutes;
  final _manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    _estimateRoute();
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _estimateRoute() async {
    final store = context.read<TripStore>();
    final api = context.read<TripApi>();
    try {
      final result = await api.estimateTrip(store.draft);
      if (!mounted) return;
      store.setEstimatedSeconds(result.durationSeconds);
      setState(() {
        _estimate = result;
        _status = _Status.success;
      });
    } catch (_) {
      if (mounted) setState(() => _status = _Status.failure);
    }
  }

  int get _minutes =>
      _editedMinutes ?? ((_estimate?.durationSeconds ?? 0) / 60).round();

  void _goToTopic() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const TopicScreen()));

  void _continueAfterFailure() {
    final minutes = int.tryParse(_manual.text.trim());
    if (minutes == null || minutes <= 0) return;
    context.read<TripStore>().setManualSeconds(minutes * 60);
    _goToTopic();
  }

  void _continueAfterSuccess() {
    if (_editing) context.read<TripStore>().setManualSeconds(_minutes * 60);
    _goToTopic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: switch (_status) {
        _Status.loading => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        _Status.failure => _failure(),
        _Status.success => _success(),
      },
    );
  }

  Widget _failure() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Route estimation failed', style: displayStyle(34)),
      const SizedBox(height: 20),
      RetryNotice(
        headline: "Couldn't estimate this route.",
        message:
            'Set your travel time manually to continue creating your audio capsule.',
        actionLabel: 'Continue',
        icon: Icons.alt_route_rounded,
        onRetry: _continueAfterFailure,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('manual-minutes'),
                controller: _manual,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Estimated Travel Time',
                  hintText: '45',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 12),
              child: Text(
                'mins',
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _success() {
    final draft = context.watch<TripStore>().draft;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Trip check', style: displayStyle(38)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRANSPORT MODE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (draft.transportMode ?? TransportMode.other).label,
                      style: displayStyle(26).copyWith(letterSpacing: 0),
                    ),
                    const Divider(height: 28, color: Color(0xFFDCDEE4)),
                    const Text(
                      'From',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      draft.startLabel ?? '',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'To',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      draft.endLabel ?? '',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_editing)
                DurationStepper(
                  minutes: _minutes,
                  onChanged: (m) => setState(() => _editedMinutes = m),
                  onUseManualTime: () {
                    context.read<TripStore>().setManualSeconds(_minutes * 60);
                    setState(() => _editing = false);
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_minutes',
                            style: displayStyle(80).copyWith(letterSpacing: 0),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'min',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'ESTIMATED DURATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      IconButton.filled(
                        tooltip: 'Edit duration',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.text,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => setState(() {
                          _editedMinutes = _minutes;
                          _editing = true;
                        }),
                        icon: const Icon(Icons.edit_rounded, size: 20),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: PrimaryButton(
              label: 'Continue',
              onPressed: _continueAfterSuccess,
            ),
          ),
        ),
      ],
    );
  }
}
