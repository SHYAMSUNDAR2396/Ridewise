import {
  calculateTargetSeconds,
  splitIntoSegments,
  withRetry,
  type AudioSegment,
  type Capsule,
  type CreateCapsuleRequest,
} from "@commute-capsule/domain";
import {
  GenerationError,
  type GenerationProgress,
  type ScriptWriter,
  type SpeechEngine,
} from "./types";

// Short segments keep each speech call quick, so playback can begin early and a
// failed segment is cheap to retry.
const MAX_SEGMENT_CHARS = 600;
const WORDS_PER_MINUTE = 150;
const SHORTENING_FACTOR = 0.85;

export type PipelineDeps = {
  script: ScriptWriter;
  speech: SpeechEngine;
  segmentPath: (capsuleId: string, index: number) => string;
  newId: () => string;
  now: () => Date;
  /** Deletes any audio already written for a capsule. */
  cleanup: (capsuleId: string) => Promise<void>;
  onProgress?: (progress: GenerationProgress) => void;
};

/**
 * Writes a script, speaks it segment by segment, and returns a capsule that
 * finishes before the trip does. Published audio never exceeds the target:
 * on overrun it makes one shorter attempt, then fails with CAPSULE_TOO_LONG
 * instead of cutting audio mid-sentence.
 */
export async function createCapsuleOnDevice(
  request: CreateCapsuleRequest,
  deps: PipelineDeps,
): Promise<Capsule> {
  const tripSeconds = request.trip.manualSeconds ?? request.trip.estimatedSeconds;
  if (!tripSeconds || tripSeconds <= 0) {
    throw new GenerationError("ROUTE_UNAVAILABLE", "Set a trip time to continue.");
  }

  const targetSeconds = calculateTargetSeconds(tripSeconds);
  const id = deps.newId();
  let targetWords = Math.round((targetSeconds / 60) * WORDS_PER_MINUTE);

  for (let attempt = 0; attempt < 2; attempt += 1) {
    deps.onProgress?.({ phase: "script", done: 0, total: 1 });
    let script;
    try {
      script = await deps.script.write({ topic: request.topic, style: request.style, targetWords });
    } catch {
      throw new GenerationError(
        "SCRIPT_GENERATION_FAILED",
        "We couldn't write your capsule's script. Please try again.",
      );
    }

    const texts = splitIntoSegments(script.transcript, MAX_SEGMENT_CHARS);
    const segments: AudioSegment[] = [];
    let audioSeconds = 0;
    let overran = false;

    for (const [index, text] of texts.entries()) {
      deps.onProgress?.({ phase: "voice", done: index, total: texts.length });
      const path = deps.segmentPath(id, index);
      let result: { durationSeconds: number };
      try {
        result = await withRetry(() => deps.speech.synthesizeToFile(text, path));
      } catch {
        await deps.cleanup(id);
        throw new GenerationError(
          "SPEECH_SYNTHESIS_FAILED",
          "We couldn't record your capsule's audio. Please try again.",
        );
      }

      audioSeconds += result.durationSeconds;
      segments.push({ index, url: `file://${path}`, durationSeconds: result.durationSeconds });

      // Stop speaking as soon as the audio no longer fits; the rest would be wasted work.
      if (audioSeconds > targetSeconds) {
        overran = true;
        break;
      }
    }

    if (!overran) {
      return {
        id,
        title: script.title,
        topic: request.topic,
        language: request.language,
        targetSeconds,
        audioSeconds,
        transcript: script.transcript,
        segments,
        createdAt: deps.now().toISOString(),
      };
    }

    await deps.cleanup(id);
    targetWords = Math.round(targetWords * SHORTENING_FACTOR);
  }

  throw new GenerationError(
    "CAPSULE_TOO_LONG",
    "This capsule couldn't fit your trip even after shortening. Please try again.",
  );
}
