import type { Language, ListeningStyle } from "@commute-capsule/domain";

export interface ScriptRequest {
  topic: string;
  style: ListeningStyle;
  language: Language;
  targetSeconds: number;
  targetWords: number;
}

export interface Script {
  title: string;
  transcript: string;
}

export interface SynthesisResult {
  bytes: Uint8Array;
  durationSeconds: number;
}

export interface ContentProvider {
  generateScript(request: ScriptRequest): Promise<Script>;
  synthesize(text: string, language: Language): Promise<SynthesisResult>;
}

export interface ElevenLabsConfig {
  apiKey: string;
  scriptAgentId: string;
  englishVoiceId: string;
  ttsModel: string;
}

/** Parse the Script Agent reply. Throws SCRIPT_GENERATION_FAILED on any deviation. */
export function parseScriptResponse(raw: string): Script {
  const unfenced = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");

  let parsed: unknown;
  try {
    parsed = JSON.parse(unfenced);
  } catch {
    throw new Error("SCRIPT_GENERATION_FAILED");
  }

  const candidate = parsed as Partial<Script>;
  if (
    typeof candidate?.title !== "string" ||
    typeof candidate?.transcript !== "string" ||
    candidate.title.trim() === "" ||
    candidate.transcript.trim() === ""
  ) {
    throw new Error("SCRIPT_GENERATION_FAILED");
  }

  return { title: candidate.title.trim(), transcript: candidate.transcript.trim() };
}

function buildPrompt(request: ScriptRequest): string {
  return [
    `Write a spoken audio script on the topic: ${request.topic}.`,
    `Style: ${request.style === "quick_overview" ? "a concise overview" : "a structured, deeper explanation"}.`,
    `Language: clear Indian English.`,
    `Length: approximately ${request.targetWords} words, which must be spoken in under ${request.targetSeconds} seconds.`,
    `Structure: a short opening, a useful main explanation, and a natural closing.`,
    `Be factual. Do not present uncertain claims as fact.`,
    `If the topic is unsafe, unreliable, or highly sensitive, return a script that`,
    `politely declines and suggests a safe alternative topic instead.`,
    `Respond with JSON containing exactly two keys, "title" and "transcript".`,
    `Do not use markdown fences, stage directions, or any commentary outside the JSON.`,
  ].join("\n");
}

export class ElevenLabsProvider implements ContentProvider {
  constructor(private readonly config: ElevenLabsConfig) {}

  async generateScript(request: ScriptRequest): Promise<Script> {
    const response = await fetch(
      `https://api.elevenlabs.io/v1/convai/conversations/simulate`,
      {
        method: "POST",
        headers: {
          "xi-api-key": this.config.apiKey,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          agent_id: this.config.scriptAgentId,
          message: buildPrompt(request),
        }),
      },
    );

    if (!response.ok) throw new Error("SCRIPT_GENERATION_FAILED");
    return parseScriptResponse(await response.text());
  }

  async synthesize(text: string, language: Language): Promise<SynthesisResult> {
    const voiceId = this.voiceFor(language);
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: "POST",
        headers: {
          "xi-api-key": this.config.apiKey,
          "content-type": "application/json",
          accept: "audio/mpeg",
        },
        body: JSON.stringify({ text, model_id: this.config.ttsModel }),
      },
    );

    // The provider body may contain the key or voice id. It is never rethrown.
    if (!response.ok) throw new Error("SPEECH_SYNTHESIS_FAILED");

    const bytes = new Uint8Array(await response.arrayBuffer());
    return { bytes, durationSeconds: estimateMp3Seconds(bytes) };
  }

  private voiceFor(language: Language): string {
    if (language === "en-IN") return this.config.englishVoiceId;
    throw new Error("SPEECH_SYNTHESIS_FAILED");
  }
}

/**
 * Duration from encoded size at the provider's default 128 kbps MP3 output.
 * Ceiling: this is an estimate, and the capsule budget is a hard ceiling.
 * Replace with a real MP3 frame count if measured drift ever exceeds a second.
 */
function estimateMp3Seconds(bytes: Uint8Array): number {
  const bitsPerSecond = 128_000;
  return (bytes.byteLength * 8) / bitsPerSecond;
}

/** Deterministic provider for development and tests. Never contacts a network. */
export class DevelopmentProvider implements ContentProvider {
  async generateScript(request: ScriptRequest): Promise<Script> {
    const sentence = `This is a development capsule about ${request.topic}.`;
    // Deliberately undershoot the budget so development output never trips the
    // shortening path and tests assert the happy route.
    const count = Math.max(1, Math.floor((request.targetWords * 0.9) / 8));
    return {
      title: `Development capsule: ${request.topic}`,
      transcript: Array.from({ length: count }, () => sentence).join(" "),
    };
  }

  async synthesize(text: string): Promise<SynthesisResult> {
    const words = text.split(/\s+/).filter(Boolean).length;
    return {
      bytes: new Uint8Array(text.length),
      durationSeconds: (words / 150) * 60,
    };
  }
}
