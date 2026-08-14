import Fastify, { type FastifyInstance } from "fastify";
import { ZodError } from "zod";
import { loadConfig } from "./config";
import { GoogleRoutingProvider } from "./providers/routing";
import { DevelopmentRoutingProvider } from "./providers/development";
import { ElevenLabsProvider, DevelopmentProvider } from "./providers/elevenlabs";
import { InMemoryStorage, S3Storage } from "./providers/storage";
import { TripService } from "./services/trip-service";
import { CapsuleService } from "./services/capsule-service";
import { registerTripRoutes } from "./routes/trips";
import { registerCapsuleRoutes } from "./routes/capsules";

function buildDefaultTripService(): TripService {
  const config = loadConfig();
  const routing =
    config.providerMode === "production"
      ? new GoogleRoutingProvider(config.googleMapsApiKey as string)
      : new DevelopmentRoutingProvider();
  return new TripService(routing);
}

function buildDefaultCapsuleService(): CapsuleService {
  const config = loadConfig();
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
  tripService?: TripService;
  capsuleService?: CapsuleService;
}): FastifyInstance {
  const app = Fastify();
  const tripService = overrides?.tripService ?? buildDefaultTripService();
  const capsuleService = overrides?.capsuleService ?? buildDefaultCapsuleService();

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({ error: "INVALID_REQUEST" });
    }
    app.log.error(error);
    return reply.status(500).send({ error: "INTERNAL_ERROR" });
  });

  registerTripRoutes(app, tripService);
  registerCapsuleRoutes(app, tripService, capsuleService);

  return app;
}
