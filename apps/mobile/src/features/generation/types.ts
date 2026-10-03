import type { CapsuleErrorCode, ListeningStyle } from "@commute-capsule/domain";

/** A local language model. Implemented over llama.rn on device and by fakes in tests. */
export interface TextModel {
  complete(prompt: string, maxTokens: number): Promise<string>;
}

/** A local speech engine that writes one WAV file per call. */
export interface SpeechEngine {
  synthesizeToFile(text: string, filePath: string): Promise<{ durationSeconds: number }>;
}

export type ScriptRequest = {
  topic: string;
  style: ListeningStyle;
  targetWords: number;
};

export type Script = { title: string; transcript: string };

export interface ScriptWriter {
  write(request: ScriptRequest): Promise<Script>;
}

export type GenerationProgress = {
  phase: "script" | "voice";
  done: number;
  total: number;
};

/** Same stable codes the server API used, so screens branch on one set. */
export class GenerationError extends Error {
  constructor(
    readonly code: CapsuleErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "GenerationError";
  }
}
