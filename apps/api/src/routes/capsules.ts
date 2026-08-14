import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { transportModes } from "@commute-capsule/domain";
import type { TripService } from "../services/trip-service";
import type { CapsuleService } from "../services/capsule-service";

const tripDraftSchema = z.object({
  startLabel: z.string().min(1),
  endLabel: z.string().min(1),
  transportMode: z.enum(transportModes),
  estimatedSeconds: z.number().positive().optional(),
  manualSeconds: z.number().positive().optional(),
});

export const createCapsuleSchema = z.object({
  trip: tripDraftSchema,
  topic: z.string().min(1),
  style: z.enum(["quick_overview", "learn_deeply"]),
  language: z.literal("en-IN"),
});

export function registerCapsuleRoutes(
  app: FastifyInstance,
  tripService: TripService,
  capsuleService: CapsuleService,
): void {
  app.post("/v1/capsules", async (request, reply) => {
    const input = createCapsuleSchema.parse(request.body);
    const trip = await tripService.estimate(input.trip);
    const capsule = await capsuleService.create(input, trip.durationSeconds);
    return reply.code(201).send(capsule);
  });
}
