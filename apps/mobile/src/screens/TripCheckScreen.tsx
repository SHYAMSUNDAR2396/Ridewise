import React, { useEffect, useState } from "react";
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
import type { RouteEstimate, TransportMode, TripDraft } from "@commute-capsule/domain";
import { apiClient } from "../api/client";
import { Icon } from "../components/Icon";
import { PrimaryButton } from "../components/PrimaryButton";
import { RetryNotice } from "../components/RetryNotice";
import { DurationStepper } from "../features/trip/duration-input";
import { useTripStore } from "../features/trip/trip-store";
import { useAppNavigation } from "../navigation/useAppNavigation";
import { colors, fonts } from "../theme";

const TRANSPORT_LABELS: Record<TransportMode, string> = {
  metro: "Metro",
  bus: "Bus",
  local_train: "Local train",
  car: "Cab or car",
  bike: "Bike",
  walk: "Walk",
  other: "Other",
};

type EstimateStatus = "loading" | "success" | "failure";

export function TripCheckScreen(): React.JSX.Element {
  const navigation = useAppNavigation();
  const draft = useTripStore((state) => state.draft);
  const setManualSeconds = useTripStore((state) => state.setManualSeconds);
  const setEstimatedSeconds = useTripStore((state) => state.setEstimatedSeconds);

  const [status, setStatus] = useState<EstimateStatus>("loading");
  const [estimate, setEstimate] = useState<RouteEstimate | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editedMinutes, setEditedMinutes] = useState<number | null>(null);
  const [manualMinutesInput, setManualMinutesInput] = useState("");

  useEffect(() => {
    let cancelled = false;
    setStatus("loading");
    apiClient
      .estimateTrip(draft as TripDraft)
      .then((result) => {
        if (cancelled) return;
        setEstimate(result);
        setEstimatedSeconds(result.durationSeconds);
        setStatus("success");
      })
      .catch(() => {
        if (cancelled) return;
        setStatus("failure");
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function goToTopic(): void {
    navigation.navigate("Topic");
  }

  function handleFailureContinue(): void {
    const minutes = parseInt(manualMinutesInput, 10);
    if (Number.isNaN(minutes) || minutes <= 0) return;
    setManualSeconds(minutes * 60);
    goToTopic();
  }

  function handleSuccessContinue(): void {
    if (isEditing) {
      setManualSeconds(minutes * 60);
    }
    goToTopic();
  }

  if (status === "loading") {
    return (
      <SafeAreaView style={styles.container} edges={["bottom"]}>
        <ActivityIndicator style={styles.loadingIndicator} color={colors.accent} />
      </SafeAreaView>
    );
  }

  if (status === "failure") {
    return (
      <SafeAreaView style={styles.container} edges={["bottom"]}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>Route estimation failed</Text>
          <RetryNotice
            headline="Couldn't estimate this route."
            message="Set your travel time manually to continue creating your audio capsule."
            actionLabel="Continue"
            onRetry={handleFailureContinue}
            icon="route"
          >
            <View>
              <Text style={styles.inputLabel}>Estimated Travel Time</Text>
              <View style={styles.manualInputRow}>
                <TextInput
                  accessibilityLabel="Estimated Travel Time"
                  style={styles.manualInput}
                  keyboardType="numeric"
                  placeholder="45"
                  placeholderTextColor={colors.textMuted}
                  value={manualMinutesInput}
                  onChangeText={setManualMinutesInput}
                />
                <Text style={styles.minsSuffix}>mins</Text>
              </View>
            </View>
          </RetryNotice>
        </ScrollView>
      </SafeAreaView>
    );
  }

  const minutes = editedMinutes ?? Math.round((estimate?.durationSeconds ?? 0) / 60);

  return (
    <SafeAreaView style={styles.container} edges={["bottom"]}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>Trip check</Text>

        <View style={styles.routeCard}>
          <Text style={styles.routeCardLabel}>TRANSPORT MODE</Text>
          <Text style={styles.routeCardValue}>
            {TRANSPORT_LABELS[draft.transportMode ?? "other"]}
          </Text>
          <View style={styles.timeline}>
            <Text style={styles.timelineLabel}>From</Text>
            <Text style={styles.timelineValue}>{draft.startLabel}</Text>
            <Text style={styles.timelineLabel}>To</Text>
            <Text style={styles.timelineValue}>{draft.endLabel}</Text>
          </View>
        </View>

        {isEditing ? (
          <DurationStepper
            minutes={minutes}
            onChangeMinutes={setEditedMinutes}
            onUseManualTime={() => {
              setManualSeconds(minutes * 60);
              setIsEditing(false);
            }}
          />
        ) : (
          <View style={styles.durationSection}>
            <View style={styles.durationRow}>
              <Text style={styles.durationNumber}>{minutes}</Text>
              <Text style={styles.durationUnit}>min</Text>
            </View>
            <Text style={styles.durationLabel}>Estimated Duration</Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Edit duration"
              style={styles.editButton}
              onPress={() => {
                setEditedMinutes(minutes);
                setIsEditing(true);
              }}
            >
              <Icon name="edit" size={20} color={colors.text} />
            </Pressable>
          </View>
        )}
      </ScrollView>
      <View style={styles.footer}>
        <PrimaryButton label="Continue" onPress={handleSuccessContinue} />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  loadingIndicator: { flex: 1 },
  content: { padding: 20, gap: 20 },
  title: {
    fontFamily: fonts.serif,
    fontSize: 38,
    fontWeight: "700",
    letterSpacing: -0.5,
    color: colors.text,
  },
  inputLabel: { fontSize: 12, fontWeight: "800", letterSpacing: 0.4, color: colors.textMuted, textTransform: "uppercase" },
  manualInputRow: { flexDirection: "row", alignItems: "flex-end", gap: 16 },
  manualInput: {
    flex: 1,
    fontSize: 18,
    color: colors.text,
    borderBottomWidth: 1,
    borderColor: "#c3c6d7",
    paddingVertical: 8,
  },
  minsSuffix: { fontSize: 16, color: colors.textMuted, paddingBottom: 8 },
  routeCard: { backgroundColor: colors.surface, borderRadius: 18, padding: 20, gap: 8 },
  routeCardLabel: { fontSize: 12, fontWeight: "800", letterSpacing: 1, color: colors.textMuted },
  routeCardValue: { fontFamily: fonts.serif, fontSize: 26, fontWeight: "700", color: colors.text },
  timeline: { borderTopWidth: 1, borderColor: "#dcdee4", paddingTop: 12, marginTop: 4, gap: 2 },
  timelineLabel: { fontSize: 12, fontWeight: "700", color: colors.textMuted },
  timelineValue: { fontSize: 17, fontWeight: "700", color: colors.text, marginBottom: 8 },
  durationSection: { alignItems: "center", justifyContent: "center", paddingVertical: 24 },
  durationRow: { flexDirection: "row", alignItems: "baseline", gap: 8 },
  durationNumber: { fontFamily: fonts.serif, fontSize: 80, fontWeight: "700", color: colors.text },
  durationUnit: { fontSize: 20, fontWeight: "700", color: colors.textMuted },
  durationLabel: { fontSize: 12, fontWeight: "800", letterSpacing: 1, color: colors.textMuted, textTransform: "uppercase", marginTop: 4 },
  editButton: {
    marginTop: 16,
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: colors.surface,
    alignItems: "center",
    justifyContent: "center",
  },
  footer: { padding: 20, paddingBottom: 28 },
});
