import Fastify, { type FastifyInstance } from "fastify";
import { ZodError } from "zod";
import { loadConfig } from "./config";
import { GoogleRoutingProvider } from "./providers/routing";
import { DevelopmentRoutingProvider } from "./providers/development";
import { TripService } from "./services/trip-service";
import { registerTripRoutes } from "./routes/trips";

function buildDefaultTripService(): TripService {
  const config = loadConfig();
  const routing =
    config.providerMode === "production"
      ? new GoogleRoutingProvider(config.googleMapsApiKey as string)
      : new DevelopmentRoutingProvider();
  return new TripService(routing);
}

export function buildApp(overrides?: { tripService?: TripService }): FastifyInstance {
  const app = Fastify();
  const tripService = overrides?.tripService ?? buildDefaultTripService();

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({ error: "INVALID_REQUEST" });
    }
    app.log.error(error);
    return reply.status(500).send({ error: "INTERNAL_ERROR" });
  });

  registerTripRoutes(app, tripService);

  return app;
}
