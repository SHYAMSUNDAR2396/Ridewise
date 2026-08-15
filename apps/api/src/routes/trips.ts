import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { transportModes } from "@commute-capsule/domain";
import type { TripService } from "../services/trip-service";
import { CapsuleError } from "../services/capsule-service";

export const tripDraftSchema = z.object({
  startLabel: z.string().min(1),
  endLabel: z.string().min(1),
  transportMode: z.enum(transportModes),
  estimatedSeconds: z.number().positive().optional(),
  manualSeconds: z.number().positive().optional(),
});

export function registerTripRoutes(app: FastifyInstance, tripService: TripService): void {
  app.post("/v1/trips/estimate", async (request, reply) => {
    const input = tripDraftSchema.parse(request.body);
    try {
      return reply.send(await tripService.estimate(input));
    } catch {
      // Routing failed and TripService found no usable manual fallback --
      // never forward the provider's raw error text to the client.
      throw new CapsuleError(
        "ROUTE_UNAVAILABLE",
        "We couldn't estimate this route. Enter a manual duration to continue.",
      );
    }
  });
}
