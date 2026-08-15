import { z } from "zod";

const envSchema = z
  .object({
    PROVIDER_MODE: z.enum(["development", "production"]).default("development"),
    GOOGLE_MAPS_API_KEY: z.string().optional(),
    ELEVENLABS_API_KEY: z.string().min(1).optional(),
    ELEVENLABS_SCRIPT_AGENT_ID: z.string().min(1).optional(),
    ELEVENLABS_ENGLISH_VOICE_ID: z.string().min(1).optional(),
    ELEVENLABS_TTS_MODEL: z.string().default("eleven_multilingual_v2"),
    S3_ENDPOINT: z.string().min(1).optional(),
    S3_BUCKET: z.string().min(1).optional(),
    S3_ACCESS_KEY_ID: z.string().min(1).optional(),
    S3_SECRET_ACCESS_KEY: z.string().min(1).optional(),
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
        "S3_ENDPOINT",
        "S3_BUCKET",
        "S3_ACCESS_KEY_ID",
        "S3_SECRET_ACCESS_KEY",
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
  s3Endpoint: string | undefined;
  s3Bucket: string | undefined;
  s3AccessKeyId: string | undefined;
  s3SecretAccessKey: string | undefined;
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
    s3Endpoint: parsed.S3_ENDPOINT,
    s3Bucket: parsed.S3_BUCKET,
    s3AccessKeyId: parsed.S3_ACCESS_KEY_ID,
    s3SecretAccessKey: parsed.S3_SECRET_ACCESS_KEY,
  };
}
