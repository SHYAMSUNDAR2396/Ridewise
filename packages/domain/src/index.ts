export const transportModes = [
  "metro", "bus", "local_train", "car", "bike", "walk", "other",
] as const;
export type TransportMode = (typeof transportModes)[number];

export type ListeningStyle = "quick_overview" | "learn_deeply";

export type Language = "en-IN";

export interface TripDraft {
  startLabel: string;
  endLabel: string;
  transportMode: TransportMode;
  estimatedSeconds?: number;
  manualSeconds?: number;
}

export interface RouteEstimate {
  durationSeconds: number;
  summary: string;
  source: "routing" | "manual";
}

export interface CreateCapsuleRequest {
  trip: TripDraft;
  topic: string;
  style: ListeningStyle;
  language: Language;
}

export interface AudioSegment {
  index: number;
  url: string;
  durationSeconds: number;
}

export interface Capsule {
  id: string;
  title: string;
  topic: string;
  language: Language;
  targetSeconds: number;
  audioSeconds: number;
  transcript: string;
  segments: AudioSegment[];
  createdAt: string;
}

export const capsuleErrorCodes = [
  "ROUTE_UNAVAILABLE",
  "SCRIPT_GENERATION_FAILED",
  "SPEECH_SYNTHESIS_FAILED",
  "CAPSULE_TOO_LONG",
  "AUDIO_UNAVAILABLE",
] as const;
export type CapsuleErrorCode = (typeof capsuleErrorCodes)[number];

export function calculateTargetSeconds(tripSeconds: number): number {
  const buffer = Math.min(Math.max(Math.round(tripSeconds * 0.1), 60), 180);
  return Math.max(60, tripSeconds - buffer);
}

// Split points are the whitespace that follows a sentence terminator. The
// Devanagari danda is included so the same function serves Hindi later.
const SENTENCE_BOUNDARY = /(?<=[.!?।])\s+/;

/**
 * Split text into segments of at most `maxChars`, breaking only at complete
 * sentence boundaries. A single sentence longer than `maxChars` is emitted as
 * its own oversized segment rather than being cut mid-sentence.
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

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Retry `fn` with bounded exponential backoff. Rethrows the final error. */
export async function withRetry<T>(
  fn: () => Promise<T>,
  attempts = 3,
  baseDelayMs = 200,
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt < attempts - 1) await sleep(baseDelayMs * 2 ** attempt);
    }
  }

  throw lastError;
}
