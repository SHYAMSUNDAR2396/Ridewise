import RNBlobUtil from "react-native-blob-util";
import type { Capsule, CreateCapsuleRequest } from "@commute-capsule/domain";
import { createCapsuleOnDevice } from "../pipeline";
import { createScriptWriter } from "../script-writer";
import type { GenerationProgress } from "../types";
import { deleteCapsuleFiles } from "../../capsules/download";
import { createLlamaModel } from "./llama-model";
import { ensureModels } from "./models";
import { createSherpaSpeech } from "./sherpa-speech";

export type GenerateProgress = GenerationProgress | { phase: "models"; done: number; total: 100 };

function newId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

/** Makes a capsule entirely on this phone: Gemma writes the script, Kokoro speaks it. */
export async function generateCapsuleOnDevice(
  request: CreateCapsuleRequest,
  onProgress: (progress: GenerateProgress) => void,
): Promise<Capsule> {
  const models = await ensureModels((percent) =>
    onProgress({ phase: "models", done: percent, total: 100 }),
  );
  const speech = createSherpaSpeech(models.kokoroDir);

  try {
    return await createCapsuleOnDevice(request, {
      script: {
        // Free the language model's memory before the voice model starts working.
        async write(scriptRequest) {
          const model = createLlamaModel(models.gemmaPath);
          try {
            return await createScriptWriter(model).write(scriptRequest);
          } finally {
            await model.release();
          }
        },
      },
      speech: {
        async synthesizeToFile(text, filePath) {
          const dir = filePath.slice(0, filePath.lastIndexOf("/"));
          if (!(await RNBlobUtil.fs.exists(dir))) await RNBlobUtil.fs.mkdir(dir);
          return speech.synthesizeToFile(text, filePath);
        },
      },
      segmentPath: (capsuleId, index) =>
        `${RNBlobUtil.fs.dirs.DocumentDir}/capsules/${capsuleId}/segment-${index}.wav`,
      newId,
      now: () => new Date(),
      cleanup: (capsuleId) => deleteCapsuleFiles(capsuleId).catch(() => undefined),
      onProgress,
    });
  } finally {
    await speech.destroy();
  }
}
