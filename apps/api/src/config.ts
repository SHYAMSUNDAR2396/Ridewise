import { z } from "zod";

const envSchema = z
  .object({
    PROVIDER_MODE: z.enum(["development", "production"]).default("development"),
    GOOGLE_MAPS_API_KEY: z.string().optional(),
    ELEVENLABS_API_KEY: z.string().min(1).optional(),
    ELEVENLABS_SCRIPT_AGENT_ID: z.string().min(1).optional(),
    ELEVENLABS_ENGLISH_VOICE_ID: z.string().min(1).optional(),
    ELEVENLABS_TTS_MODEL: z.string().default("eleven_multilingual_v2"),
  })
  .superRefine((env, ctx) => {
    if (env.PROVIDER_MODE === "production" && !env.GOOGLE_MAPS_API_KEY) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["GOOGLE_MAPS_API_KEY"],
        message: "GOOGLE_MAPS_API_KEY is required when PROVIDER_MODE=production",
      });
    }
    if (env.PROVIDER_MODE === "production") {
      for (const key of [
        "ELEVENLABS_API_KEY",
        "ELEVENLABS_SCRIPT_AGENT_ID",
        "ELEVENLABS_ENGLISH_VOICE_ID",
      ] as const) {
        if (!env[key]) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: [key],
            message: `${key} is required when PROVIDER_MODE=production`,
          });
        }
      }
    }
  });

export type Config = {
  providerMode: "development" | "production";
  googleMapsApiKey: string | undefined;
  elevenLabsApiKey: string | undefined;
  elevenLabsScriptAgentId: string | undefined;
  elevenLabsEnglishVoiceId: string | undefined;
  elevenLabsTtsModel: string;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = envSchema.parse(env);
  return {
    providerMode: parsed.PROVIDER_MODE,
    googleMapsApiKey: parsed.GOOGLE_MAPS_API_KEY,
    elevenLabsApiKey: parsed.ELEVENLABS_API_KEY,
    elevenLabsScriptAgentId: parsed.ELEVENLABS_SCRIPT_AGENT_ID,
    elevenLabsEnglishVoiceId: parsed.ELEVENLABS_ENGLISH_VOICE_ID,
    elevenLabsTtsModel: parsed.ELEVENLABS_TTS_MODEL,
  };
}
