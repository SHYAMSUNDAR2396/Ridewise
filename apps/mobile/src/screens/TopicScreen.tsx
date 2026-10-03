import React, { useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import type { ListeningStyle, TripDraft } from "@commute-capsule/domain";
import { Chip } from "../components/Chip";
import { GradientFill } from "../components/Artwork";
import { PrimaryButton } from "../components/PrimaryButton";
import { RetryNotice } from "../components/RetryNotice";
import { useGenerateCapsule } from "../features/capsules/generate-capsule";
import type { GenerateProgress } from "../features/generation/native/runtime";
import { useTripStore } from "../features/trip/trip-store";
import { useAppNavigation } from "../navigation/useAppNavigation";
import { colors, fonts } from "../theme";

const TOPIC_SUGGESTIONS = [
  "India and the world",
  "Careers",
  "Personal finance",
  "Technology",
  "History",
  "Language",
];

const STYLE_OPTIONS: { value: ListeningStyle; title: string; description: string }[] = [
  {
    value: "quick_overview",
    title: "Quick overview",
    description: "Key highlights. Best for short rides.",
  },
  {
    value: "learn_deeply",
    title: "Learn deeply",
    description: "In-depth context. Ideal for longer rides.",
  },
];

function progressLabel(progress: GenerateProgress | null): string {
  if (progress?.phase === "models") return `Getting ready, ${progress.done}%`;
  if (progress?.phase === "script") return "Writing your script...";
  if (progress?.phase === "voice") return `Recording part ${progress.done + 1} of ${progress.total}...`;
  return "Preparing your capsule...";
}

export function TopicScreen(): React.JSX.Element {
  const navigation = useAppNavigation();
  const draft = useTripStore((state) => state.draft);
  const { generate, status, progress } = useGenerateCapsule();

  const [selectedChip, setSelectedChip] = useState<string | null>(null);
  const [customTopic, setCustomTopic] = useState("");
  const [style, setStyle] = useState<ListeningStyle>("quick_overview");

  const topic = customTopic.trim() !== "" ? customTopic.trim() : (selectedChip ?? "");
  const duration = draft.manualSeconds ?? draft.estimatedSeconds;
  const canGenerate = topic.length > 0 && typeof duration === "number" && duration > 0;

  function selectChip(value: string): void {
    setSelectedChip(value);
    setCustomTopic("");
  }

  function handleCustomTopicChange(text: string): void {
    setCustomTopic(text);
    if (text.trim() !== "") setSelectedChip(null);
  }

  async function handleGenerate(): Promise<void> {
    if (!canGenerate) return;
    try {
      const capsule = await generate({
        trip: draft as TripDraft,
        topic,
        style,
        language: "en-IN",
      });
      navigation.navigate("Player", { capsule });
    } catch {
      // status flips to "error" below; topic/style/language/trip selections are untouched
      // so the Retry button can resubmit the same request.
    }
  }

  return (
    <SafeAreaView style={styles.container} edges={["bottom"]}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.heading}>What should we cover?</Text>

        <View style={styles.chipRow}>
          {TOPIC_SUGGESTIONS.map((suggestion) => (
            <Chip
              key={suggestion}
              label={suggestion}
              selected={selectedChip === suggestion && customTopic.trim() === ""}
              onPress={() => selectChip(suggestion)}
            />
          ))}
        </View>

        <TextInput
          accessibilityLabel="Custom topic"
          style={styles.customInput}
          placeholder="Or type your own topic"
          placeholderTextColor={colors.textMuted}
          value={customTopic}
          onChangeText={handleCustomTopicChange}
        />

        <Text style={styles.sectionLabel}>LISTENING STYLE</Text>
        <View style={styles.styleCards}>
          {STYLE_OPTIONS.map((option) => {
            const isSelected = style === option.value;
            return (
              <Pressable
                key={option.value}
                accessibilityRole="button"
                accessibilityLabel={option.title}
                accessibilityState={{ selected: isSelected }}
                style={[styles.styleCard, isSelected && styles.styleCardSelected]}
                onPress={() => setStyle(option.value)}
              >
                <Text style={styles.styleCardTitle}>{option.title}</Text>
                <Text style={styles.styleCardDescription}>{option.description}</Text>
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.sectionLabel}>LANGUAGE</Text>
        <View style={styles.languageSegment}>
          <View style={styles.languageOptionActive}>
            <Text style={styles.languageOptionActiveText}>English</Text>
          </View>
          <View
            accessibilityRole="button"
            accessibilityState={{ disabled: true }}
            style={styles.languageOption}
          >
            <Text style={styles.languageOptionText}>Hindi</Text>
            <View style={styles.soonBadge}>
              <Text style={styles.soonBadgeText}>Soon</Text>
            </View>
          </View>
        </View>

        {status === "error" ? (
          <RetryNotice
            headline="Your capsule needs another moment."
            message="Something went wrong, and your selections are saved. Try again."
            actionLabel="Retry"
            onRetry={handleGenerate}
            icon="alert"
          />
        ) : null}
      </ScrollView>

      <View style={styles.footer}>
        <PrimaryButton label="Generate my capsule" disabled={!canGenerate} onPress={handleGenerate} />
      </View>

      {status === "loading" ? (
        <View style={styles.loadingOverlay}>
          <GradientFill from={colors.playerTop} to={colors.playerBottom} id="loading" />
          <ActivityIndicator color={colors.onPlayer} size="large" />
          <Text style={styles.loadingText}>{progressLabel(progress)}</Text>
          {progress?.phase === "models" ? (
            <Text style={styles.loadingHint}>Downloading the voice and writer once. They stay on this phone.</Text>
          ) : null}
        </View>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  content: { padding: 20, gap: 18, paddingBottom: 120 },
  heading: {
    fontFamily: fonts.serif,
    fontSize: 38,
    fontWeight: "700",
    letterSpacing: -0.5,
    lineHeight: 42,
    color: colors.text,
  },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  customInput: {
    height: 48,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: "#dcdee4",
    paddingHorizontal: 16,
    fontSize: 15,
    color: colors.text,
  },
  sectionLabel: { fontSize: 12, fontWeight: "800", letterSpacing: 0.3, color: colors.textMuted },
  styleCards: { flexDirection: "row", gap: 12 },
  styleCard: {
    flex: 1,
    borderRadius: 16,
    borderWidth: 2,
    borderColor: colors.line,
    padding: 14,
    gap: 4,
  },
  styleCardSelected: { borderColor: colors.accent, backgroundColor: colors.accentSoft },
  styleCardTitle: { fontSize: 15, fontWeight: "800", color: colors.text },
  styleCardDescription: { fontSize: 13, lineHeight: 18, color: "#434a58" },
  languageSegment: {
    height: 48,
    padding: 2,
    borderRadius: 14,
    backgroundColor: colors.surface,
    flexDirection: "row",
  },
  languageOptionActive: {
    flex: 1,
    borderRadius: 12,
    backgroundColor: "#ffffff",
    alignItems: "center",
    justifyContent: "center",
  },
  languageOptionActiveText: { fontSize: 14, fontWeight: "800", color: colors.text },
  languageOption: {
    flex: 1,
    flexDirection: "row",
    gap: 6,
    alignItems: "center",
    justifyContent: "center",
  },
  languageOptionText: { fontSize: 14, fontWeight: "700", color: colors.textMuted },
  soonBadge: { borderRadius: 8, backgroundColor: colors.line, paddingHorizontal: 6, paddingVertical: 2 },
  soonBadgeText: { fontSize: 10, fontWeight: "800", color: colors.textMuted },
  footer: { position: "absolute", left: 0, right: 0, bottom: 0, padding: 20, paddingBottom: 28, backgroundColor: colors.bg },
  loadingOverlay: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    alignItems: "center",
    justifyContent: "center",
    gap: 16,
    overflow: "hidden",
  },
  loadingText: { fontFamily: fonts.serif, fontSize: 24, fontWeight: "700", color: colors.onPlayer, textAlign: "center", paddingHorizontal: 24 },
  loadingHint: { fontSize: 14, color: colors.onPlayerMuted, textAlign: "center", paddingHorizontal: 32 },
});
