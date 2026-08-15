import type { AudioSegment } from "@commute-capsule/domain";

/**
 * Map an absolute capsule position to the segment that contains it and the
 * offset within that segment. Used for resume and seek across ordered files.
 */
export function segmentAt(
  segments: AudioSegment[],
  positionSeconds: number,
): { index: number; offsetSeconds: number } {
  if (segments.length === 0) return { index: 0, offsetSeconds: 0 };
  if (positionSeconds <= 0) return { index: 0, offsetSeconds: 0 };

  let remaining = positionSeconds;
  for (const segment of segments) {
    if (remaining < segment.durationSeconds) {
      return { index: segment.index, offsetSeconds: remaining };
    }
    remaining -= segment.durationSeconds;
  }

  const last = segments[segments.length - 1];
  return { index: last.index, offsetSeconds: last.durationSeconds };
}
