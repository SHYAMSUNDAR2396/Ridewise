import React from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import type { TransportMode } from "@commute-capsule/domain";
import { Artwork, GradientFill } from "../components/Artwork";
import { EmptyState } from "../components/EmptyState";
import { Icon } from "../components/Icon";
import { useCapsuleStore, type StoredCapsule } from "../features/capsules/capsule-store";
import { useTripStore } from "../features/trip/trip-store";
import { useAppNavigation } from "../navigation/useAppNavigation";
import { colors, fonts } from "../theme";

const MODE_LABELS: Record<TransportMode, string> = {
  metro: "Metro",
  bus: "Bus",
  local_train: "Local train",
  car: "Cab or car",
  bike: "Bike",
  walk: "Walk",
  other: "Other",
};

function minutesLabel(totalSeconds: number): string {
  return `${Math.max(1, Math.round(totalSeconds / 60))} min`;
}

function languageLabel(language: string): string {
  return language === "en-IN" ? "English" : language;
}

/** Listen Now: the next ride, what was made recently, and what is still in progress. */
export function HomeScreen(): React.JSX.Element {
  const navigation = useAppNavigation();
  const draft = useTripStore((state) => state.draft);
  const capsules = useCapsuleStore((state) => state.capsules);

  const hasTrip = Boolean(draft.startLabel && draft.endLabel);
  const inProgress = capsules.filter(
    (item) => item.progressSeconds > 0 && item.progressSeconds < item.audioSeconds,
  );

  const openPlayer = (capsule: StoredCapsule): void => navigation.navigate("Player", { capsule });

  return (
    <SafeAreaView style={styles.container} edges={["top"]}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.headerRow}>
          <Text style={styles.title}>Listen Now</Text>
        </View>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Plan a capsule"
          style={styles.hero}
          onPress={() => navigation.navigate("Plan")}
        >
          <GradientFill from={colors.accent} to={colors.playerMid} id="hero" />
          <View>
            <Text style={styles.heroEyebrow}>{hasTrip ? "NEXT RIDE" : "NEW RIDE"}</Text>
            <Text style={styles.heroTitle}>
              {hasTrip ? `${draft.startLabel} to ${draft.endLabel}` : "Where are you headed?"}
            </Text>
            <Text style={styles.heroMeta}>
              {hasTrip && draft.transportMode
                ? MODE_LABELS[draft.transportMode]
                : "We will time a capsule to your trip."}
            </Text>
          </View>
          <View style={styles.heroButton}>
            <Icon name="play" size={16} color={colors.accentInk} />
            <Text style={styles.heroButtonText}>Plan a capsule</Text>
          </View>
        </Pressable>

        <Text style={styles.sectionTitle}>Recently made</Text>
        {capsules.length === 0 ? (
          <EmptyState title="No capsules yet" message="Plan a ride and your first capsule will show up here." />
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.shelf}>
            {capsules.slice(0, 8).map((capsule) => (
              <Pressable
                key={capsule.id}
                accessibilityRole="button"
                accessibilityLabel={capsule.title}
                style={styles.card}
                onPress={() => openPlayer(capsule)}
              >
                <Artwork seed={capsule.id} size={148} radius={14} />
                <Text style={styles.cardTitle} numberOfLines={2}>
                  {capsule.title}
                </Text>
                <Text style={styles.cardMeta}>
                  {languageLabel(capsule.language)}, {minutesLabel(capsule.audioSeconds)}
                </Text>
              </Pressable>
            ))}
          </ScrollView>
        )}

        {inProgress.length > 0 ? (
          <>
            <Text style={styles.sectionTitle}>Continue listening</Text>
            {inProgress.slice(0, 3).map((capsule) => (
              <Pressable
                key={capsule.id}
                accessibilityRole="button"
                accessibilityLabel={`Continue ${capsule.title}`}
                style={styles.row}
                onPress={() => openPlayer(capsule)}
              >
                <Artwork seed={capsule.id} size={48} radius={9} />
                <View style={styles.rowText}>
                  <Text style={styles.rowTitle} numberOfLines={1}>
                    {capsule.title}
                  </Text>
                  <Text style={styles.cardMeta}>
                    {capsule.topic}, {minutesLabel(capsule.audioSeconds - capsule.progressSeconds)} left
                  </Text>
                </View>
              </Pressable>
            ))}
          </>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  content: { padding: 20, gap: 14, paddingBottom: 24 },
  headerRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  title: {
    fontFamily: fonts.serif,
    fontSize: 38,
    fontWeight: "700",
    letterSpacing: -0.5,
    color: colors.text,
  },
  hero: {
    minHeight: 168,
    borderRadius: 22,
    padding: 20,
    overflow: "hidden",
    justifyContent: "space-between",
    gap: 16,
  },
  heroEyebrow: { fontSize: 12, fontWeight: "800", letterSpacing: 1.2, color: "rgba(255,255,255,0.85)" },
  heroTitle: { fontFamily: fonts.serif, fontSize: 27, fontWeight: "700", color: colors.onAccent, marginTop: 4 },
  heroMeta: { fontSize: 14, fontWeight: "500", color: "rgba(255,255,255,0.9)", marginTop: 2 },
  heroButton: {
    alignSelf: "flex-start",
    height: 44,
    paddingHorizontal: 18,
    borderRadius: 22,
    backgroundColor: "#ffffff",
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  heroButtonText: { fontSize: 14, fontWeight: "800", color: colors.accentInk },
  sectionTitle: { fontSize: 20, fontWeight: "800", letterSpacing: -0.2, color: colors.text, marginTop: 8 },
  shelf: { gap: 14, paddingRight: 20 },
  card: { width: 148, gap: 8 },
  cardTitle: { fontSize: 14, fontWeight: "700", color: colors.text },
  cardMeta: { fontSize: 13, color: colors.textMuted },
  row: { flexDirection: "row", alignItems: "center", gap: 12, minHeight: 64 },
  rowText: { flex: 1 },
  rowTitle: { fontSize: 15, fontWeight: "700", color: colors.text },
});
