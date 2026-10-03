import RNBlobUtil from "react-native-blob-util";
import { ModelCategory, ensureModel } from "react-native-sherpa-onnx/download";

export const KOKORO_MODEL_ID = "kokoro-int8-multi-lang-v1_0";

// Community GGUF build of Gemma 3 1B (instruction tuned, 4-bit). Not gated.
const GEMMA_FILE = "gemma-3-1b-it-Q4_K_M.gguf";
const GEMMA_URL = `https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/${GEMMA_FILE}`;
const GEMMA_BYTES = 806_058_272;

export type ModelsReady = { kokoroDir: string; gemmaPath: string };

/** Downloads the voice and writer models on first use. `onPercent` reports 0 to 100 across both. */
export async function ensureModels(onPercent: (percent: number) => void): Promise<ModelsReady> {
  const modelsDir = `${RNBlobUtil.fs.dirs.DocumentDir}/models`;
  const gemmaPath = `${modelsDir}/${GEMMA_FILE}`;

  const kokoro = await ensureModel(ModelCategory.Tts, KOKORO_MODEL_ID, {
    onProgress: (progress) => onPercent(Math.round(progress.percent * 0.15)),
  });

  const hasGemma =
    (await RNBlobUtil.fs.exists(gemmaPath)) &&
    Number((await RNBlobUtil.fs.stat(gemmaPath)).size) === GEMMA_BYTES;

  if (!hasGemma) {
    if (!(await RNBlobUtil.fs.exists(modelsDir))) await RNBlobUtil.fs.mkdir(modelsDir);
    const partial = `${gemmaPath}.part`;
    await RNBlobUtil.config({ path: partial })
      .fetch("GET", GEMMA_URL)
      .progress((received, total) => {
        const ratio = Number(total) > 0 ? Number(received) / Number(total) : 0;
        onPercent(15 + Math.round(ratio * 85));
      });
    await RNBlobUtil.fs.mv(partial, gemmaPath);
  }

  onPercent(100);
  return { kokoroDir: kokoro.localPath, gemmaPath };
}
