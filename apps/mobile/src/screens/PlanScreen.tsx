import React from "react";
import { ScrollView, StyleSheet, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import type { TransportMode } from "@commute-capsule/domain";
import { TripForm } from "../features/trip/trip-form";
import { useTripStore } from "../features/trip/trip-store";
import { useAppNavigation } from "../navigation/useAppNavigation";
import { colors, fonts } from "../theme";

export function PlanScreen(): React.JSX.Element {
  const navigation = useAppNavigation();
  const setEndpoints = useTripStore((state) => state.setEndpoints);
  const setTransportMode = useTripStore((state) => state.setTransportMode);

  function handleContinue(startLabel: string, endLabel: string, mode: TransportMode): void {
    setEndpoints(startLabel, endLabel);
    setTransportMode(mode);
    navigation.navigate("TripCheck");
  }

  return (
    <SafeAreaView style={styles.container} edges={["top"]}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.title}>Plan a ride</Text>
        <Text style={styles.subtitle}>Tell us where you are going and we will time the capsule to the trip.</Text>
        <TripForm onContinue={handleContinue} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  content: { padding: 20, gap: 12 },
  title: {
    fontFamily: fonts.serif,
    fontSize: 38,
    fontWeight: "700",
    letterSpacing: -0.5,
    color: colors.text,
  },
  subtitle: { fontSize: 15, lineHeight: 21, color: colors.textMuted, marginBottom: 8 },
});
