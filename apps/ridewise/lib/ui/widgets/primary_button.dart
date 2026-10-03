import 'package:flutter/material.dart';
import '../../theme.dart';

/// 56px pill. A null [onPressed] disables it.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
