import type { ListeningStyle } from "@commute-capsule/domain";
import type { ScriptWriter, TextModel } from "./types";

// A 1B-class local model loses the thread and the format on long outputs, so a
// script is written as a short outline and then one section at a time.
const WORDS_PER_SECTION = 300;
const TOKENS_PER_WORD = 1.6;
const MAX_OUTLINE_TOKENS = 200;

const STYLE_HINT: Record<ListeningStyle, string> = {
  quick_overview: "a concise overview that gets to the point",
  learn_deeply: "a deeper explanation with context and examples",
};

function stripMarkup(line: string): string {
  return line
    .replace(/^[\s>*#\-•\d.)]+/, "")
    .replace(/[*_`#]/g, "")
    .trim();
}

export function parseOutline(raw: string, sectionCount: number): { title: string; headings: string[] } {
  const lines = raw
    .split("\n")
    .map((line) => stripMarkup(line.replace(/^title\s*:/i, "")))
    .filter((line) => line.length > 0);

  const [title, ...rest] = lines;
  if (!title) throw new Error("SCRIPT_GENERATION_FAILED");
  const headings = rest.slice(0, sectionCount);
  return { title, headings: headings.length > 0 ? headings : [title] };
}

/** Removes markdown, bracketed stage directions and leftover labels so the voice never reads them aloud. */
export function cleanSection(raw: string): string {
  return raw
    .replace(/\[[^\]]*\]|\([^)]*\)/g, " ")
    .split("\n")
    .map((line) => line.replace(/^[\s>*#\-•]+/, "").replace(/[*_`]/g, "").trim())
    .filter((line) => line.length > 0 && !/^(section|part|title|heading)\b[^.!?]*:$/i.test(line))
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
}

function lastSentence(text: string): string {
  const sentences = text.split(/(?<=[.!?])\s+/).filter(Boolean);
  return sentences[sentences.length - 1] ?? "";
}

function outlinePrompt(topic: string, style: ListeningStyle, sectionCount: number): string {
  return [
    `Plan a spoken audio talk about: ${topic}.`,
    `It should be ${STYLE_HINT[style]}.`,
    `Reply with the talk's title on the first line, then exactly ${sectionCount} lines, each a short heading for one part of the talk, in order.`,
    "No numbering, no extra text.",
  ].join("\n");
}

function sectionPrompt(args: {
  topic: string;
  style: ListeningStyle;
  title: string;
  heading: string;
  index: number;
  total: number;
  words: number;
  previous: string;
}): string {
  const position =
    args.total === 1
      ? "This is the whole talk: give a short opening, the main idea, and a natural closing."
      : args.index === 0
        ? "This is the opening: welcome the listener briefly, then begin."
        : args.index === args.total - 1
          ? "This is the final part: finish the idea and close the talk naturally."
          : "This is a middle part: continue naturally without a greeting or a goodbye.";

  return [
    `You are writing one part of a spoken audio talk titled "${args.title}" about ${args.topic}.`,
    `Style: ${STYLE_HINT[args.style]}. Write in clear Indian English.`,
    `Write about ${args.words} words for the part called "${args.heading}". ${position}`,
    args.previous ? `The previous part ended with: "${args.previous}"` : "",
    "Write plain spoken sentences only. No headings, no lists, no markdown, no stage directions, no sound effects.",
    "Be factual and do not present uncertain claims as fact.",
  ]
    .filter(Boolean)
    .join("\n");
}

export function createScriptWriter(model: TextModel): ScriptWriter {
  return {
    async write({ topic, style, targetWords }) {
      const sectionCount = Math.max(1, Math.round(targetWords / WORDS_PER_SECTION));

      let outline: { title: string; headings: string[] };
      try {
        outline = parseOutline(
          await model.complete(outlinePrompt(topic, style, sectionCount), MAX_OUTLINE_TOKENS),
          sectionCount,
        );
      } catch {
        throw new Error("SCRIPT_GENERATION_FAILED");
      }

      const total = outline.headings.length;
      const words = Math.round(targetWords / total);
      const sections: string[] = [];

      for (const [index, heading] of outline.headings.entries()) {
        let text: string;
        try {
          text = cleanSection(
            await model.complete(
              sectionPrompt({
                topic,
                style,
                title: outline.title,
                heading,
                index,
                total,
                words,
                previous: lastSentence(sections[index - 1] ?? ""),
              }),
              Math.ceil(words * TOKENS_PER_WORD) + 60,
            ),
          );
        } catch {
          throw new Error("SCRIPT_GENERATION_FAILED");
        }
        if (text.length === 0) throw new Error("SCRIPT_GENERATION_FAILED");
        sections.push(text);
      }

      return { title: outline.title, transcript: sections.join(" ") };
    },
  };
}
