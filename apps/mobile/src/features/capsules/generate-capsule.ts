import { useCallback, useState } from "react";
import type { Capsule, CreateCapsuleRequest } from "@commute-capsule/domain";
import {
  generateCapsuleOnDevice,
  type GenerateProgress,
} from "../generation/native/runtime";

export type GenerateCapsuleStatus = "idle" | "loading" | "error";

export function useGenerateCapsule(): {
  generate(input: CreateCapsuleRequest): Promise<Capsule>;
  status: GenerateCapsuleStatus;
  progress: GenerateProgress | null;
} {
  const [status, setStatus] = useState<GenerateCapsuleStatus>("idle");
  const [progress, setProgress] = useState<GenerateProgress | null>(null);

  const generate = useCallback(async (input: CreateCapsuleRequest): Promise<Capsule> => {
    setStatus("loading");
    setProgress(null);
    try {
      const capsule = await generateCapsuleOnDevice(input, setProgress);
      setStatus("idle");
      return capsule;
    } catch (error) {
      setStatus("error");
      throw error;
    } finally {
      setProgress(null);
    }
  }, []);

  return { generate, status, progress };
}
