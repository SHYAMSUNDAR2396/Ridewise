import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/generation_controller.dart';
import '../../theme.dart';

/// A small "Generating" label for the capsule that is being made right now. Empty for any other capsule.
class GeneratingTag extends StatelessWidget {
  const GeneratingTag({super.key, required this.capsuleId});

  final String capsuleId;

  @override
  Widget build(BuildContext context) {
    final gen = context.watch<GenerationController>();
    if (!gen.isGenerating || gen.activeCapsuleId != capsuleId) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Generating',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
