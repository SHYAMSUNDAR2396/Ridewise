import { initLlama, type LlamaContext } from "llama.rn";
import type { TextModel } from "../types";

const STOP_WORDS = ["<end_of_turn>", "</s>", "<|im_end|>"];

export type LlamaTextModel = TextModel & { release: () => Promise<void> };

/** A GGUF model (Gemma) running locally through llama.cpp. It loads on first use. */
export function createLlamaModel(modelPath: string): LlamaTextModel {
  let context: Promise<LlamaContext> | undefined;

  const getContext = (): Promise<LlamaContext> => {
    context ??= initLlama({ model: modelPath, n_ctx: 4096, n_gpu_layers: 0 });
    return context;
  };

  return {
    async complete(prompt, maxTokens) {
      const llama = await getContext();
      const result = await llama.completion({
        messages: [{ role: "user", content: prompt }],
        n_predict: maxTokens,
        temperature: 0.7,
        stop: STOP_WORDS,
      });
      return result.text;
    },
    async release() {
      if (!context) return;
      const current = await context;
      context = undefined;
      await current.release();
    },
  };
}
