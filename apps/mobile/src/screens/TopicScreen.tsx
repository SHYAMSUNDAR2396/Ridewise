import React, { useState } from "react";
import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import {
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import type { ListeningStyle, TripDraft } from "@commute-capsule/domain";
import { useTripStore } from "../features/trip/trip-store";
import { useGenerateCapsule } from "../features/capsules/generate-capsule";
import type { RootStackParamList } from "../navigation/RootNavigator";

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
    description: "Key highlights and summaries. Perfect for short commutes.",
  },
  {
    value: "learn_deeply",
    title: "Learn deeply",
    description: "In-depth analysis and context. Ideal for longer journeys.",
  },
];

export function TopicScreen(): React.JSX.Element {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const draft = useTripStore((state) => state.draft);
  const { generate, status } = useGenerateCapsule();

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
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.heading}>What do you want to hear about?</Text>

        <View style={styles.chipRow}>
          {TOPIC_SUGGESTIONS.map((suggestion) => {
            const isSelected = selectedChip === suggestion && customTopic.trim() === "";
            return (
              <Pressable
                key={suggestion}
                accessibilityRole="button"
                style={[styles.chip, isSelected && styles.chipSelected]}
                onPress={() => selectChip(suggestion)}
              >
                <Text style={[styles.chipText, isSelected && styles.chipTextSelected]}>
                  {suggestion}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <TextInput
          accessibilityLabel="Custom topic"
          style={styles.customInput}
          placeholder="Or type your own topic..."
          value={customTopic}
          onChangeText={handleCustomTopicChange}
        />

        <Text style={styles.sectionLabel}>Listening Style</Text>
        <View style={styles.styleCards}>
          {STYLE_OPTIONS.map((option) => {
            const isSelected = style === option.value;
            return (
              <Pressable
                key={option.value}
                accessibilityRole="button"
                accessibilityLabel={option.title}
                style={[styles.styleCard, isSelected && styles.styleCardSelected]}
                onPress={() => setStyle(option.value)}
              >
                <Text style={styles.styleCardTitle}>{option.title}</Text>
                <Text style={styles.styleCardDescription}>{option.description}</Text>
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.sectionLabel}>Language</Text>
        <View style={styles.languageSegment}>
          <View style={styles.languageOptionActive}>
            <Text style={styles.languageOptionActiveText}>English</Text>
          </View>
          <View
            accessibilityRole="button"
            accessibilityState={{ disabled: true }}
            style={styles.languageOptionDisabled}
          >
            <Text style={styles.languageOptionDisabledText}>Hindi</Text>
            <View style={styles.soonBadge}>
              <Text style={styles.soonBadgeText}>Soon</Text>
            </View>
          </View>
        </View>

        {status === "error" ? (
          <View style={styles.errorBanner}>
            <Text style={styles.errorText}>
              Something went wrong. Your selections are saved -- try again.
            </Text>
            <Pressable
              accessibilityRole="button"
              style={styles.retryButton}
              onPress={handleGenerate}
            >
              <Text style={styles.retryButtonText}>Retry</Text>
            </Pressable>
          </View>
        ) : null}
      </ScrollView>

      <View style={styles.footer}>
        <Pressable
          accessibilityRole="button"
          disabled={!canGenerate}
          style={[styles.generateButton, !canGenerate && styles.generateButtonDisabled]}
          onPress={handleGenerate}
        >
          <Text style={styles.generateButtonText}>Generate my capsule</Text>
        </Pressable>
      </View>

      {status === "loading" ? (
        <View style={styles.loadingOverlay}>
          <View style={styles.pulseDots}>
            <View style={styles.pulseDot} />
            <View style={styles.pulseDot} />
            <View style={styles.pulseDot} />
          </View>
          <Text style={styles.loadingText}>Preparing your capsule...</Text>
        </View>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f9f9f9",
  },
  content: {
    padding: 24,
    gap: 24,
    paddingBottom: 120,
  },
  heading: {
    fontFamily: "Newsreader",
    fontSize: 24,
    fontWeight: "500",
    color: "#1a1c1c",
  },
  chipRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
  },
  chip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: "#c3c6d7",
  },
  chipSelected: {
    backgroundColor: "#2563eb",
    borderColor: "#2563eb",
  },
  chipText: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#1a1c1c",
  },
  chipTextSelected: {
    color: "#ffffff",
  },
  customInput: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#1a1c1c",
    borderBottomWidth: 1,
    borderColor: "#c3c6d7",
    paddingVertical: 12,
  },
  sectionLabel: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.6,
    textTransform: "uppercase",
    color: "#434655",
  },
  styleCards: {
    gap: 16,
  },
  styleCard: {
    padding: 24,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#c3c6d7",
    backgroundColor: "#ffffff",
    gap: 4,
  },
  styleCardSelected: {
    borderColor: "#2563eb",
    backgroundColor: "#f0f7ff",
  },
  styleCardTitle: {
    fontFamily: "Manrope",
    fontSize: 18,
    fontWeight: "600",
    color: "#1a1c1c",
  },
  styleCardDescription: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#434655",
  },
  languageSegment: {
    flexDirection: "row",
    padding: 4,
    borderRadius: 12,
    backgroundColor: "#eeeeee",
    maxWidth: 320,
  },
  languageOptionActive: {
    flex: 1,
    paddingVertical: 8,
    alignItems: "center",
    borderRadius: 8,
    backgroundColor: "#ffffff",
  },
  languageOptionActiveText: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    color: "#1a1c1c",
  },
  languageOptionDisabled: {
    flex: 1,
    paddingVertical: 8,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 4,
    opacity: 0.5,
  },
  languageOptionDisabledText: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    color: "#434655",
  },
  soonBadge: {
    backgroundColor: "#e2e2e2",
    borderRadius: 4,
    paddingHorizontal: 4,
    paddingVertical: 1,
  },
  soonBadgeText: {
    fontFamily: "Manrope",
    fontSize: 10,
    color: "#434655",
  },
  errorBanner: {
    gap: 12,
    padding: 16,
    borderRadius: 12,
    backgroundColor: "#ffdad6",
  },
  errorText: {
    fontFamily: "Manrope",
    fontSize: 14,
    color: "#93000a",
  },
  retryButton: {
    alignSelf: "flex-start",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#93000a",
  },
  retryButtonText: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    color: "#93000a",
  },
  footer: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    padding: 24,
    backgroundColor: "#f9f9f9",
  },
  generateButton: {
    width: "100%",
    paddingVertical: 16,
    borderRadius: 12,
    backgroundColor: "#2563eb",
    alignItems: "center",
  },
  generateButtonDisabled: {
    opacity: 0.4,
  },
  generateButtonText: {
    fontFamily: "Manrope",
    fontSize: 16,
    fontWeight: "700",
    color: "#ffffff",
  },
  loadingOverlay: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(249, 249, 249, 0.9)",
    alignItems: "center",
    justifyContent: "center",
    gap: 16,
  },
  pulseDots: {
    flexDirection: "row",
    gap: 8,
  },
  pulseDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: "#dc2c4f",
  },
  loadingText: {
    fontFamily: "Newsreader",
    fontSize: 24,
    fontWeight: "500",
    color: "#1a1c1c",
  },
});
