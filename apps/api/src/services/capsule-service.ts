import { randomUUID } from "node:crypto";
import {
  calculateTargetSeconds,
  type Capsule,
  type AudioSegment,
  type CreateCapsuleRequest,
  type CapsuleErrorCode,
} from "@commute-capsule/domain";
import type { ContentProvider } from "../providers/elevenlabs";
import type { Storage } from "../providers/storage";
import { splitIntoSegments } from "./segmenter";
import { withRetry } from "./retry";

const MAX_SEGMENT_CHARS = 8_000;
const WORDS_PER_MINUTE = 150;
const SHORTENING_FACTOR = 0.85;

/**
 * The API's stable, five-code error shape. Exactly the codes in
 * @commute-capsule/domain's `capsuleErrorCodes` -- no `UNSAFE_TOPIC`, no
 * `suggestedTopic`. An unsafe-topic decline from the Script Agent is a
 * normal published capsule, never a thrown error.
 */
export class CapsuleError extends Error {
  constructor(
    readonly code: CapsuleErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "CapsuleError";
  }
}

export class CapsuleService {
  constructor(
    private readonly provider: ContentProvider,
    private readonly storage: Storage,
  ) {}

  async create(request: CreateCapsuleRequest, tripSeconds: number): Promise<Capsule> {
    const targetSeconds = calculateTargetSeconds(tripSeconds);
    const id = randomUUID();

    let targetWords = Math.round((targetSeconds / 60) * WORDS_PER_MINUTE);
    let attempt = 0;

    // One generation attempt, then one shortened retry, then give up.
    while (attempt < 2) {
      const script = await this.provider.generateScript({
        topic: request.topic,
        style: request.style,
        language: request.language,
        targetSeconds,
        targetWords,
      });

      const segments = await this.synthesizeSegments(id, script.transcript, request);
      const audioSeconds = segments.reduce((sum, s) => sum + s.durationSeconds, 0);

      if (audioSeconds <= targetSeconds) {
        return {
          id,
          title: script.title,
          topic: request.topic,
          language: request.language,
          targetSeconds,
          audioSeconds,
          transcript: script.transcript,
          segments,
          createdAt: new Date().toISOString(),
        };
      }

      targetWords = Math.round(targetWords * SHORTENING_FACTOR);
      attempt += 1;
    }

    throw new CapsuleError(
      "CAPSULE_TOO_LONG",
      "CAPSULE_TOO_LONG: this capsule couldn't fit the trip's duration even after shortening.",
    );
  }

  /** Synthesize sequentially so a retry never regenerates a successful segment. */
  private async synthesizeSegments(
    capsuleId: string,
    transcript: string,
    request: CreateCapsuleRequest,
  ): Promise<AudioSegment[]> {
    const texts = splitIntoSegments(transcript, MAX_SEGMENT_CHARS);
    const segments: AudioSegment[] = [];

    for (const [index, text] of texts.entries()) {
      const result = await withRetry(() =>
        this.provider.synthesize(text, request.language),
      );
      let url: string;
      try {
        url = await this.storage.put(`${capsuleId}/${index}.mp3`, result.bytes);
      } catch {
        // Storage failures never reach the client as raw provider/SDK text --
        // reuse the same known-code convention providers/elevenlabs.ts uses so
        // routes/capsules.ts's existing FRIENDLY_MESSAGES mapping handles this
        // too. SPEECH_SYNTHESIS_FAILED reads truer than AUDIO_UNAVAILABLE
        // here: this segment's audio was never successfully produced, whereas
        // AUDIO_UNAVAILABLE is reserved for a client-side playback failure on
        // audio that *was* published (see docs/product/operations.md).
        throw new Error("SPEECH_SYNTHESIS_FAILED");
      }
      segments.push({ index, url, durationSeconds: result.durationSeconds });
    }

    return segments;
  }
}
