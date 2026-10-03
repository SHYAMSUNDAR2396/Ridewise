import 'package:flutter/material.dart';
import '../../theme.dart';

/// Failure card: icon, headline, body, optional extra content, one action.
class RetryNotice extends StatelessWidget {
  const RetryNotice({
    super.key,
    required this.headline,
    required this.message,
    required this.actionLabel,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.child,
  });

  final String headline;
  final String message;
  final String actionLabel;
  final VoidCallback onRetry;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: AppColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 12), child!],
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: actionLabel,
            excludeSemantics: true,
            onTap: onRetry,
            child: Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onRetry,
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
