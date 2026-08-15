import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { TripService } from "../services/trip-service";
import { CapsuleError, type CapsuleService } from "../services/capsule-service";
import { tripDraftSchema } from "./trips";

/**
 * Provider errors surface from apps/api/src/providers/elevenlabs.ts as plain
 * `Error`s whose message is already one of these constant code strings (see
 * SCRIPT_GENERATION_FAILED / SPEECH_SYNTHESIS_FAILED there) -- never
 * provider response bodies, API keys, or raw provider error text. This map
 * turns that known, safe string into the stable CapsuleError shape.
 */
const FRIENDLY_MESSAGES: Record<string, string> = {
  SCRIPT_GENERATION_FAILED: "We couldn't generate your capsule's script. Please try again.",
  SPEECH_SYNTHESIS_FAILED: "We couldn't generate the audio for your capsule. Please try again.",
};

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

    let tripSeconds: number;
    try {
      tripSeconds = (await tripService.estimate(input.trip)).durationSeconds;
    } catch {
      throw new CapsuleError(
        "ROUTE_UNAVAILABLE",
        "We couldn't estimate this route. Enter a manual duration to continue.",
      );
    }

    try {
      const capsule = await capsuleService.create(input, tripSeconds);
      return reply.code(201).send(capsule);
    } catch (error) {
      if (error instanceof CapsuleError) throw error;
      const code = error instanceof Error ? error.message : "";
      if (code in FRIENDLY_MESSAGES) {
        throw new CapsuleError(code as "SCRIPT_GENERATION_FAILED" | "SPEECH_SYNTHESIS_FAILED", FRIENDLY_MESSAGES[code]);
      }
      throw error;
    }
  });
}
