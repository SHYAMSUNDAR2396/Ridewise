import { z } from "zod";

const envSchema = z
  .object({
    PROVIDER_MODE: z.enum(["development", "production"]).default("development"),
    GOOGLE_MAPS_API_KEY: z.string().optional(),
  })
  .superRefine((env, ctx) => {
    if (env.PROVIDER_MODE === "production" && !env.GOOGLE_MAPS_API_KEY) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["GOOGLE_MAPS_API_KEY"],
        message: "GOOGLE_MAPS_API_KEY is required when PROVIDER_MODE=production",
      });
    }
  });

export type Config = {
  providerMode: "development" | "production";
  googleMapsApiKey: string | undefined;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = envSchema.parse(env);
  return {
    providerMode: parsed.PROVIDER_MODE,
    googleMapsApiKey: parsed.GOOGLE_MAPS_API_KEY,
  };
}
