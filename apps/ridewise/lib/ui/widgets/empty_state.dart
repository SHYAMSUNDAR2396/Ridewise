import 'package:flutter/material.dart';
import '../../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.headphones_rounded,
            size: 32,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: displayStyle(22)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
