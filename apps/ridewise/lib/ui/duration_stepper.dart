import 'package:flutter/material.dart';
import '../theme.dart';

class DurationStepper extends StatefulWidget {
  const DurationStepper({
    super.key,
    required this.minutes,
    required this.onChanged,
    required this.onUseManualTime,
  });

  final int minutes;
  final ValueChanged<int> onChanged;
  final VoidCallback onUseManualTime;

  @override
  State<DurationStepper> createState() => _DurationStepperState();
}

class _DurationStepperState extends State<DurationStepper> {
  late final _controller = TextEditingController(text: '${widget.minutes}');

  @override
  void didUpdateWidget(DurationStepper old) {
    super.didUpdateWidget(old);
    // Keep the field in step with the +/- buttons without fighting the user's typing.
    if (int.tryParse(_controller.text) != widget.minutes) {
      _controller.text = '${widget.minutes}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.minutes;
    final onChanged = widget.onChanged;
    final onUseManualTime = widget.onUseManualTime;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            'About $minutes minutes',
            textAlign: TextAlign.center,
            style: displayStyle(
              30,
              color: AppColors.accent,
            ).copyWith(letterSpacing: 0),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 260,
            child: Text(
              'Adjust this if your ride usually takes longer or shorter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                label: 'Decrease minutes',
                onPressed: minutes > 1 ? () => onChanged(minutes - 1) : null,
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  key: const Key('stepper-minutes'),
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: displayStyle(40),
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null && parsed > 0) onChanged(parsed);
                  },
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                label: 'Increase minutes',
                onPressed: () => onChanged(minutes + 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onUseManualTime,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(
              'USE MANUAL TIME',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      minimumSize: const Size(56, 56),
    ),
    icon: Icon(icon, size: 22),
  );
}
