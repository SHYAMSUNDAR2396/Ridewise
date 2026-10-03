/// Sentence splitting and retry, shared by the generation pipeline.
library;

// Split points are the whitespace that follows a sentence terminator. The
// Devanagari danda is included so the same function serves Hindi.
final _sentenceBoundary = RegExp(r'(?<=[.!?।])\s+');

/// Split text into segments of at most [maxChars], breaking only at complete
/// sentence boundaries. A single sentence longer than [maxChars] becomes its
/// own oversized segment rather than being cut mid-sentence.
List<String> splitIntoSegments(String text, int maxChars) {
  final sentences =
      text.trim().split(_sentenceBoundary).where((s) => s.isNotEmpty);
  final segments = <String>[];
  var current = '';

  for (final sentence in sentences) {
    if (current.isNotEmpty && current.length + 1 + sentence.length > maxChars) {
      segments.add(current);
      current = sentence;
    } else {
      current = current.isEmpty ? sentence : '$current $sentence';
    }
  }

  if (current.isNotEmpty) segments.add(current);
  return segments;
}

/// Retry [fn] with bounded exponential backoff. Rethrows the final error.
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int attempts = 3,
  Duration baseDelay = const Duration(milliseconds: 200),
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await fn();
    } catch (_) {
      if (attempt >= attempts - 1) rethrow;
      await Future<void>.delayed(baseDelay * (1 << attempt));
    }
  }
}
