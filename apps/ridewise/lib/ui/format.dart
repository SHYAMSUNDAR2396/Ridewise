/// 372.4 -> "6:12".
String formatClock(double seconds) {
  final total = seconds.isNaN ? 0 : seconds.round().clamp(0, 1 << 30);
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// 2100 -> "35 min", 4500 -> "1 hr 15 min".
String formatMinutes(double seconds) {
  final minutes = (seconds / 60).round().clamp(1, 1 << 20);
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}
