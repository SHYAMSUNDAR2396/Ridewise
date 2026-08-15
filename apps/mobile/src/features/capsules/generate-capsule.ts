import { useCallback, useState } from "react";
import type { Capsule, CreateCapsuleRequest } from "@commute-capsule/domain";
import { apiClient } from "../../api/client";

export type GenerateCapsuleStatus = "idle" | "loading" | "error";

export function useGenerateCapsule(): {
  generate(input: CreateCapsuleRequest): Promise<Capsule>;
  status: GenerateCapsuleStatus;
} {
  const [status, setStatus] = useState<GenerateCapsuleStatus>("idle");

  const generate = useCallback(async (input: CreateCapsuleRequest): Promise<Capsule> => {
    setStatus("loading");
    try {
      const capsule = await apiClient.createCapsule(input);
      setStatus("idle");
      return capsule;
    } catch (error) {
      setStatus("error");
      throw error;
    }
  }, []);

  return { generate, status };
}
