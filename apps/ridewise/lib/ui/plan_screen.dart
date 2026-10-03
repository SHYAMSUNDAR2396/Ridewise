import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/trip_store.dart';
import '../domain/models.dart';
import '../theme.dart';
import 'trip_check_screen.dart';
import 'widgets/pill_chip.dart';
import 'widgets/primary_button.dart';

/// Plan a ride: from, to and how you are travelling.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  TransportMode? _mode;
  String? _error;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _continue() {
    final error = _start.text.trim().isEmpty
        ? 'Enter a starting point'
        : _end.text.trim().isEmpty
        ? 'Enter a destination'
        : _mode == null
        ? 'Choose how you are travelling'
        : null;
    setState(() => _error = error);
    if (error != null) return;

    context.read<TripStore>()
      ..setEndpoints(_start.text, _end.text)
      ..setTransportMode(_mode!);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TripCheckScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Plan a ride', style: displayStyle(38)),
          const SizedBox(height: 8),
          const Text(
            'Tell us where you are going and we will time the capsule to the trip.',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  const _Rail(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _Field(
                          label: 'FROM',
                          semanticLabel: 'Start',
                          controller: _start,
                          hint: 'e.g. Rajiv Chowk',
                          divider: true,
                        ),
                        _Field(
                          label: 'TO',
                          semanticLabel: 'Destination',
                          controller: _end,
                          hint: 'e.g. Hauz Khas',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'HOW ARE YOU TRAVELLING',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in TransportMode.values)
                PillChip(
                  label: m.label,
                  selected: _mode == m,
                  onPressed: () => setState(() => _mode = m),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Continue', onPressed: _continue),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 14,
    child: Column(
      children: [
        SizedBox(height: 30),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 10, height: 10),
        ),
        Expanded(child: _Dots()),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.text,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          child: SizedBox(width: 10, height: 10),
        ),
        SizedBox(height: 30),
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotsPainter(), size: Size.infinite);
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF9AA1B0);
    for (var y = 4.0; y < size.height - 2; y += 6) {
      canvas.drawCircle(Offset(size.width / 2, y), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.semanticLabel,
    required this.controller,
    required this.hint,
    this.divider = false,
  });

  final String label;
  final String semanticLabel;
  final TextEditingController controller;
  final String hint;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: Color(0xFFDCDEE4)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.textMuted,
            ),
          ),
          Semantics(
            label: semanticLabel,
            child: TextField(
              key: Key('plan-$semanticLabel'),
              controller: controller,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
