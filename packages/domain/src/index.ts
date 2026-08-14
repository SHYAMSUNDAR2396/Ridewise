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
