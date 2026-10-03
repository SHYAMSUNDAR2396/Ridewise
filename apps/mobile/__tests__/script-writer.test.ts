import { cleanSection, createScriptWriter, parseOutline } from "../src/features/generation/script-writer";
import type { TextModel } from "../src/features/generation/types";

function fakeModel(replies: string[]): TextModel & { prompts: string[] } {
  const prompts: string[] = [];
  return {
    prompts,
    async complete(prompt) {
      prompts.push(prompt);
      const reply = replies.shift();
      if (reply === undefined) throw new Error("no more replies");
      return reply;
    },
  };
}

describe("parseOutline", () => {
  it("takes the first line as the title and strips numbering and markdown", () => {
    const outline = parseOutline("Title: **Index Funds**\n1. What they are\n2) Why fees matter\n- Getting started", 3);
    expect(outline).toEqual({
      title: "Index Funds",
      headings: ["What they are", "Why fees matter", "Getting started"],
    });
  });

  it("ignores extra headings and falls back to the title when there are none", () => {
    expect(parseOutline("T\nA\nB\nC", 2).headings).toEqual(["A", "B"]);
    expect(parseOutline("Only a title", 3).headings).toEqual(["Only a title"]);
  });

  it("rejects an empty reply", () => {
    expect(() => parseOutline("  \n ", 2)).toThrow("SCRIPT_GENERATION_FAILED");
  });
});

describe("cleanSection", () => {
  it("removes markdown, stage directions and label lines", () => {
    const raw = "**Part 1:**\n[soft music]\n- Welcome to the show (pause) everyone.\n# Heading\nThis is *fine*.";
    expect(cleanSection(raw)).toBe("Welcome to the show everyone. Heading This is fine.");
  });
});

describe("createScriptWriter", () => {
  it("writes an outline, then one section at a time, carrying the last sentence forward", async () => {
    const model = fakeModel([
      "Money Basics\nWhat money is\nSaving early",
      "Money is a tool. It stores value.",
      "Start saving early. Small amounts grow.",
    ]);

    const script = await createScriptWriter(model).write({
      topic: "Personal finance",
      style: "quick_overview",
      targetWords: 600,
    });

    expect(script.title).toBe("Money Basics");
    expect(script.transcript).toBe("Money is a tool. It stores value. Start saving early. Small amounts grow.");
    expect(model.prompts).toHaveLength(3);
    expect(model.prompts[0]).toContain("exactly 2 lines");
    expect(model.prompts[2]).toContain('The previous part ended with: "It stores value."');
    expect(model.prompts[1]).toContain("This is the opening");
    expect(model.prompts[2]).toContain("This is the final part");
  });

  it("fails with SCRIPT_GENERATION_FAILED when the model errors or returns nothing", async () => {
    const writer = (replies: string[]) =>
      createScriptWriter(fakeModel(replies)).write({ topic: "x", style: "quick_overview", targetWords: 300 });

    await expect(writer([])).rejects.toThrow("SCRIPT_GENERATION_FAILED");
    await expect(writer(["Title\nOne", "[music]"])).rejects.toThrow("SCRIPT_GENERATION_FAILED");
  });
});
