/// <reference types="vitest" />
import { describe, it, expect } from "vitest";
import { loadConfig } from "../src/config";

describe("loadConfig", () => {
  it("does not require any provider credentials in development mode", () => {
    expect(() => loadConfig({ PROVIDER_MODE: "development" })).not.toThrow();
  });

  it("throws when PROVIDER_MODE=production is missing a required credential", () => {
    // server.ts's fail-closed startup relies on this throwing synchronously --
    // this is the mechanism under test, not the process-exit path itself.
    expect(() =>
      loadConfig({
        PROVIDER_MODE: "production",
        GOOGLE_MAPS_API_KEY: "key",
        // ELEVENLABS_API_KEY intentionally omitted.
        ELEVENLABS_SCRIPT_AGENT_ID: "agent",
        ELEVENLABS_ENGLISH_VOICE_ID: "voice",
        S3_ENDPOINT: "https://s3.example.com",
        S3_BUCKET: "bucket",
        S3_ACCESS_KEY_ID: "id",
        S3_SECRET_ACCESS_KEY: "secret",
      }),
    ).toThrow();
  });

  it("succeeds in production mode when every required credential is present", () => {
    expect(() =>
      loadConfig({
        PROVIDER_MODE: "production",
        GOOGLE_MAPS_API_KEY: "key",
        ELEVENLABS_API_KEY: "eleven-key",
        ELEVENLABS_SCRIPT_AGENT_ID: "agent",
        ELEVENLABS_ENGLISH_VOICE_ID: "voice",
        S3_ENDPOINT: "https://s3.example.com",
        S3_BUCKET: "bucket",
        S3_ACCESS_KEY_ID: "id",
        S3_SECRET_ACCESS_KEY: "secret",
      }),
    ).not.toThrow();
  });
});
