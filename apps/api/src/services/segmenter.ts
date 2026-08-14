// Split points are the whitespace that follows a sentence terminator. The
// Devanagari danda is included so the same function serves Hindi later.
const SENTENCE_BOUNDARY = /(?<=[.!?।])\s+/;

/**
 * Split text into segments of at most `maxChars`, breaking only at complete
 * sentence boundaries.
 *
 * Ceiling: a single sentence longer than `maxChars` is emitted as its own
 * oversized segment rather than being cut mid-sentence. The provider will
 * reject it and the caller surfaces SPEECH_SYNTHESIS_FAILED. Splitting at
 * clause boundaries is the upgrade path if real scripts ever hit this.
 */
export function splitIntoSegments(text: string, maxChars: number): string[] {
  const sentences = text.trim().split(SENTENCE_BOUNDARY).filter(Boolean);
  const segments: string[] = [];
  let current = "";

  for (const sentence of sentences) {
    if (current && current.length + 1 + sentence.length > maxChars) {
      segments.push(current);
      current = sentence;
    } else {
      current = current ? `${current} ${sentence}` : sentence;
    }
  }

  if (current) segments.push(current);
  return segments;
}
