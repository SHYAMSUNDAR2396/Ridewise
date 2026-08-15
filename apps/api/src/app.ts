import Fastify, { type FastifyInstance } from "fastify";
import { ZodError } from "zod";
import type { CapsuleErrorCode } from "@commute-capsule/domain";
import { loadConfig, type Config } from "./config";
import { GoogleRoutingProvider } from "./providers/routing";
import { DevelopmentRoutingProvider } from "./providers/development";
import { ElevenLabsProvider, DevelopmentProvider } from "./providers/elevenlabs";
import { InMemoryStorage, S3Storage } from "./providers/storage";
import { TripService } from "./services/trip-service";
import { CapsuleService, CapsuleError } from "./services/capsule-service";
import { registerTripRoutes } from "./routes/trips";
import { registerCapsuleRoutes } from "./routes/capsules";

/** CAPSULE_TOO_LONG is a valid, expected outcome (422); the rest are upstream failures (502). */
const STATUS_BY_CAPSULE_ERROR_CODE: Record<CapsuleErrorCode, number> = {
  ROUTE_UNAVAILABLE: 502,
  SCRIPT_GENERATION_FAILED: 502,
  SPEECH_SYNTHESIS_FAILED: 502,
  CAPSULE_TOO_LONG: 422,
  AUDIO_UNAVAILABLE: 502,
};

function buildDefaultTripService(config: Config): TripService {
  const routing =
    config.providerMode === "production"
      ? new GoogleRoutingProvider(config.googleMapsApiKey as string)
      : new DevelopmentRoutingProvider();
  return new TripService(routing);
}

function buildDefaultCapsuleService(config: Config): CapsuleService {
  if (config.providerMode === "production") {
    const provider = new ElevenLabsProvider({
      apiKey: config.elevenLabsApiKey as string,
      scriptAgentId: config.elevenLabsScriptAgentId as string,
      englishVoiceId: config.elevenLabsEnglishVoiceId as string,
      ttsModel: config.elevenLabsTtsModel,
    });
    const storage = new S3Storage({
      endpoint: config.s3Endpoint as string,
      bucket: config.s3Bucket as string,
      accessKeyId: config.s3AccessKeyId as string,
      secretAccessKey: config.s3SecretAccessKey as string,
    });
    return new CapsuleService(provider, storage);
  }
  return new CapsuleService(new DevelopmentProvider(), new InMemoryStorage());
}

export function buildApp(overrides?: {
  providerMode?: "development" | "production";
  tripService?: TripService;
  capsuleService?: CapsuleService;
}): FastifyInstance {
  const app = Fastify();
  // `providerMode` is the single switch that selects development vs. production
  // implementations for routing, content generation, and storage together.
  // Passing it overrides only the mode, not the rest of loadConfig()'s env-derived
  // production credentials (still required from env when providerMode is "production").
  const config: Config = overrides?.providerMode
    ? { ...loadConfig(), providerMode: overrides.providerMode }
    : loadConfig();
  const tripService = overrides?.tripService ?? buildDefaultTripService(config);
  const capsuleService = overrides?.capsuleService ?? buildDefaultCapsuleService(config);

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({ error: "INVALID_REQUEST" });
    }
    if (error instanceof CapsuleError) {
      // error.message is always one of this file's own friendly strings --
      // never a provider response body, API key, or S3 credential.
      return reply
        .status(STATUS_BY_CAPSULE_ERROR_CODE[error.code])
        .send({ code: error.code, message: error.message });
    }
    // Unknown errors (provider network failures, etc.) are logged server-side
    // only. Never forward error.message here -- it may contain provider
    // response text, credentials, or other internal detail.
    app.log.error(error);
    return reply.status(500).send({ error: "INTERNAL_ERROR" });
  });

  registerTripRoutes(app, tripService);
  registerCapsuleRoutes(app, tripService, capsuleService);

  return app;
}
