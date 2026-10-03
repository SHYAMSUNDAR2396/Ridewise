import { createTTS, saveAudioToFile, type TtsEngine } from "react-native-sherpa-onnx/tts";
import type { SpeechEngine } from "../types";

// Kokoro speaker 3 is the American English voice "af_heart". Kokoro has no
// Indian English voice; swap the id here if another voice suits better.
const ENGLISH_SPEAKER_ID = 3;

export type SherpaSpeech = SpeechEngine & { destroy: () => Promise<void> };

/** Kokoro text-to-speech through sherpa-onnx. The engine loads on first use. */
export function createSherpaSpeech(modelDir: string): SherpaSpeech {
  let engine: Promise<TtsEngine> | undefined;

  const getEngine = (): Promise<TtsEngine> => {
    engine ??= createTTS({
      modelPath: { type: "file", path: modelDir },
      modelType: "kokoro",
      numThreads: 2,
    });
    return engine;
  };

  return {
    async synthesizeToFile(text, filePath) {
      const tts = await getEngine();
      const audio = await tts.generateSpeech(text, { sid: ENGLISH_SPEAKER_ID, speed: 1 });
      await saveAudioToFile(audio, filePath);
      return { durationSeconds: audio.samples.length / audio.sampleRate };
    },
    async destroy() {
      if (!engine) return;
      const current = await engine;
      engine = undefined;
      await current.destroy();
    },
  };
}
