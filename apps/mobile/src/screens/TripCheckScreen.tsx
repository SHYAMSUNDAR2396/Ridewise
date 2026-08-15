import React, { useEffect, useState } from "react";
import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import {
  ActivityIndicator,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import type { RouteEstimate, TransportMode, TripDraft } from "@commute-capsule/domain";
import { apiClient } from "../api/client";
import { useTripStore } from "../features/trip/trip-store";
import { DurationStepper } from "../features/trip/duration-input";
import { RetryNotice } from "../components/RetryNotice";
import type { RootStackParamList } from "../navigation/RootNavigator";

// ponytail: main-screen layout is sourced from
// stitch_ridewise_audio_companion_ui_ux/trip_check_summary/code.html -- that file (despite its
// name) holds the route-summary card + duration display + Edit button; the failure layout is
// from failure_states/code.html.

const TRANSPORT_LABELS: Record<TransportMode, string> = {
  metro: "Metro",
  bus: "Bus",
  local_train: "Local train",
  car: "Cab/car",
  bike: "Bike",
  walk: "Walk",
  other: "Other",
};

type EstimateStatus = "loading" | "success" | "failure";

export function TripCheckScreen(): React.JSX.Element {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
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
      <SafeAreaView style={styles.container}>
        <ActivityIndicator style={styles.loadingIndicator} color="#2563eb" />
      </SafeAreaView>
    );
  }

  if (status === "failure") {
    return (
      <SafeAreaView style={styles.container}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.sectionTitle}>Route Estimation Failed</Text>
          <RetryNotice
            headline="Couldn't estimate this route."
            message="Set your travel time manually to continue creating your audio capsule."
            actionLabel="Continue"
            onRetry={handleFailureContinue}
            icon="🗺"
          >
            <View>
              <Text style={styles.inputLabel}>Estimated Travel Time</Text>
              <View style={styles.manualInputRow}>
                <TextInput
                  accessibilityLabel="Estimated Travel Time"
                  style={styles.manualInput}
                  keyboardType="numeric"
                  placeholder="45"
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
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.routeCard}>
          <Text style={styles.routeCardLabel}>Transport Mode</Text>
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
              <Text style={styles.editIcon}>✎</Text>
            </Pressable>
          </View>
        )}
      </ScrollView>
      <View style={styles.footer}>
        <Pressable
          accessibilityRole="button"
          style={styles.continueButton}
          onPress={handleSuccessContinue}
        >
          <Text style={styles.continueButtonText}>Continue</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f9f9f9",
  },
  loadingIndicator: {
    flex: 1,
  },
  content: {
    padding: 24,
    gap: 24,
  },
  sectionTitle: {
    fontFamily: "Newsreader",
    fontSize: 24,
    fontWeight: "500",
    color: "#1a1c1c",
  },
  inputLabel: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.6,
    textTransform: "uppercase",
    color: "#1a1c1c",
    marginTop: 8,
  },
  manualInputRow: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 16,
  },
  manualInput: {
    flex: 1,
    fontFamily: "Manrope",
    fontSize: 18,
    color: "#1a1c1c",
    borderBottomWidth: 1,
    borderColor: "#c3c6d7",
    paddingVertical: 8,
  },
  minsSuffix: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#434655",
    paddingBottom: 8,
  },
  routeCard: {
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#c3c6d7",
    borderRadius: 12,
    padding: 24,
    gap: 12,
  },
  routeCardLabel: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.6,
    textTransform: "uppercase",
    color: "#434655",
  },
  routeCardValue: {
    fontFamily: "Newsreader",
    fontSize: 24,
    fontWeight: "500",
    color: "#1a1c1c",
  },
  timeline: {
    borderTopWidth: 1,
    borderColor: "#c3c6d7",
    paddingTop: 16,
    gap: 4,
  },
  timelineLabel: {
    fontFamily: "Manrope",
    fontSize: 13,
    color: "#434655",
  },
  timelineValue: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#1a1c1c",
    marginBottom: 8,
  },
  durationSection: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 24,
    position: "relative",
  },
  durationRow: {
    flexDirection: "row",
    alignItems: "baseline",
    gap: 8,
  },
  durationNumber: {
    fontFamily: "Newsreader",
    fontSize: 64,
    fontWeight: "600",
    color: "#1a1c1c",
  },
  durationUnit: {
    fontFamily: "Newsreader",
    fontSize: 24,
    color: "#434655",
  },
  durationLabel: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.6,
    textTransform: "uppercase",
    color: "#434655",
    marginTop: 4,
  },
  editButton: {
    position: "absolute",
    right: 0,
    top: "50%",
    marginTop: -24,
    width: 48,
    height: 48,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: "#c3c6d7",
    backgroundColor: "#ffffff",
    alignItems: "center",
    justifyContent: "center",
  },
  editIcon: {
    fontSize: 18,
    color: "#434655",
  },
  footer: {
    borderTopWidth: 1,
    borderColor: "#c3c6d7",
    backgroundColor: "#f9f9f9",
    padding: 24,
  },
  continueButton: {
    width: "100%",
    height: 56,
    borderRadius: 12,
    backgroundColor: "#2563eb",
    alignItems: "center",
    justifyContent: "center",
  },
  continueButtonText: {
    fontFamily: "Manrope",
    fontSize: 18,
    fontWeight: "700",
    color: "#ffffff",
  },
});
