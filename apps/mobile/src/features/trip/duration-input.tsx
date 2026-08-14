import React from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";

// ponytail: content sourced from stitch_ridewise_audio_companion_ui_ux/trip_check/code.html
// (the file is misnamed in the export -- its content is the manual-override stepper, while
// trip_check_summary/code.html holds the main Trip Check summary screen).

type DurationStepperProps = {
  minutes: number;
  onChangeMinutes: (minutes: number) => void;
  onUseManualTime: () => void;
};

export function DurationStepper({
  minutes,
  onChangeMinutes,
  onUseManualTime,
}: DurationStepperProps): React.JSX.Element {
  function decrease(): void {
    if (minutes > 1) onChangeMinutes(minutes - 1);
  }

  function increase(): void {
    onChangeMinutes(minutes + 1);
  }

  function handleTextChange(text: string): void {
    const parsed = parseInt(text, 10);
    if (!Number.isNaN(parsed)) onChangeMinutes(parsed);
  }

  return (
    <View style={styles.container}>
      <Text style={styles.headline}>About {minutes} minutes</Text>
      <Text style={styles.helper}>
        Adjust this if your ride usually takes longer or shorter.
      </Text>
      <View style={styles.stepperRow}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Decrease minutes"
          style={styles.stepperButton}
          onPress={decrease}
        >
          <Text style={styles.stepperIcon}>–</Text>
        </Pressable>
        <TextInput
          accessibilityLabel="Minutes"
          style={styles.stepperInput}
          keyboardType="numeric"
          value={String(minutes)}
          onChangeText={handleTextChange}
        />
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Increase minutes"
          style={styles.stepperButton}
          onPress={increase}
        >
          <Text style={styles.stepperIcon}>+</Text>
        </Pressable>
      </View>
      <Pressable accessibilityRole="button" onPress={onUseManualTime} style={styles.manualLinkWrap}>
        <Text style={styles.manualLink}>Use manual time</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "center",
    gap: 16,
    paddingVertical: 24,
  },
  headline: {
    fontFamily: "Newsreader",
    fontSize: 32,
    fontWeight: "600",
    color: "#2563eb",
    textAlign: "center",
  },
  helper: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#434655",
    textAlign: "center",
    maxWidth: 260,
  },
  stepperRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 16,
    marginTop: 8,
  },
  stepperButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    borderWidth: 1,
    borderColor: "#c3c6d7",
    backgroundColor: "#ffffff",
    alignItems: "center",
    justifyContent: "center",
  },
  stepperIcon: {
    fontSize: 22,
    color: "#1a1c1c",
  },
  stepperInput: {
    width: 96,
    textAlign: "center",
    fontFamily: "Newsreader",
    fontSize: 32,
    fontWeight: "600",
    color: "#1a1c1c",
    borderBottomWidth: 1,
    borderColor: "#c3c6d7",
    paddingVertical: 4,
  },
  manualLinkWrap: {
    marginTop: 8,
    paddingVertical: 8,
  },
  manualLink: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.6,
    textTransform: "uppercase",
    color: "#555555",
    textDecorationLine: "underline",
  },
});
