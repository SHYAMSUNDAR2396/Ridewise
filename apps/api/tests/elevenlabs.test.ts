import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ElevenLabsProvider, parseScriptResponse } from "../src/providers/elevenlabs";

const config = {
  apiKey: "test-key",
  scriptAgentId: "agent-1",
  englishVoiceId: "voice-en",
  ttsModel: "eleven_multilingual_v2",
};

describe("parseScriptResponse", () => {
  it("accepts a well-formed script", () => {
    const parsed = parseScriptResponse('{"title":"Metro Money","transcript":"A sentence."}');
    expect(parsed).toEqual({ title: "Metro Money", transcript: "A sentence." });
  });

  it("strips a markdown fence before parsing", () => {
    const parsed = parseScriptResponse('```json\n{"title":"T","transcript":"Body."}\n```');
    expect(parsed.title).toBe("T");
  });

  it("rejects a response missing the transcript", () => {
    expect(() => parseScriptResponse('{"title":"T"}')).toThrow("SCRIPT_GENERATION_FAILED");
  });

  it("rejects a response that is not JSON at all", () => {
    expect(() => parseScriptResponse("Sure! Here is your script.")).toThrow(
      "SCRIPT_GENERATION_FAILED",
    );
  });

  it("accepts a decline-shaped script as a valid script, not an error", () => {
    // The agent's own safe-alternative decline is well-formed {title, transcript} JSON.
    // Enforcement of unsafe-topic handling is entirely prompt-side (see Global
    // Constraints) — parseScriptResponse does not distinguish a decline from
    // any other script and must not throw for one.
    const parsed = parseScriptResponse(
      '{"title":"Let\'s try a different topic","transcript":"I can\'t cover that topic, but here is a safe alternative: how India\'s metro systems changed city life."}',
    );
    expect(parsed.title).toBe("Let's try a different topic");
    expect(parsed.transcript.length).toBeGreaterThan(0);
  });
});

describe("ElevenLabsProvider.synthesize", () => {
  beforeEach(() => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => new ArrayBuffer(8),
    }) as unknown as typeof fetch;
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("sends the configured English voice and model", async () => {
    const provider = new ElevenLabsProvider(config);
    await provider.synthesize("Hello.", "en-IN");

    const [url, init] = (global.fetch as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(url).toContain("voice-en");
    expect(JSON.parse(init.body as string).model_id).toBe("eleven_multilingual_v2");
  });

  it("throws a clean code and never leaks the provider body", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => "invalid api key sk-secret-123",
    }) as unknown as typeof fetch;

    const provider = new ElevenLabsProvider(config);
    await expect(provider.synthesize("Hello.", "en-IN")).rejects.toThrow(
      /^SPEECH_SYNTHESIS_FAILED$/,
    );
  });
});
