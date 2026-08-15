import React from "react";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { Pressable, SafeAreaView, StyleSheet, Text, View } from "react-native";
import type { TransportMode } from "@commute-capsule/domain";
import { useTripStore } from "../features/trip/trip-store";
import type { RootStackParamList } from "../navigation/RootNavigator";

type ModeScreenProps = NativeStackScreenProps<RootStackParamList, "Mode">;

const TRANSPORT_OPTIONS: { mode: TransportMode; label: string; icon: string }[] = [
  { mode: "metro", label: "Metro", icon: "🚇" },
  { mode: "bus", label: "Bus", icon: "🚌" },
  { mode: "local_train", label: "Local train", icon: "🚆" },
  { mode: "car", label: "Cab/car", icon: "🚗" },
  { mode: "bike", label: "Bike", icon: "🏍️" },
  { mode: "walk", label: "Walk", icon: "🚶" },
  { mode: "other", label: "Other", icon: "•••" },
];

export function ModeScreen({ navigation }: ModeScreenProps): React.JSX.Element {
  const setTransportMode = useTripStore((state) => state.setTransportMode);

  function handleSelect(mode: TransportMode): void {
    setTransportMode(mode);
    navigation.navigate("TripCheck");
  }

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>How are you traveling?</Text>
      <View style={styles.list}>
        {TRANSPORT_OPTIONS.map(({ mode, label, icon }) => (
          <Pressable
            key={mode}
            accessibilityRole="button"
            accessibilityLabel={label}
            style={styles.option}
            onPress={() => handleSelect(mode)}
          >
            <Text style={styles.icon}>{icon}</Text>
            <Text style={styles.label}>{label}</Text>
          </Pressable>
        ))}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
    padding: 20,
  },
  title: {
    fontSize: 22,
    fontWeight: "700",
    color: "#111827",
    marginBottom: 16,
  },
  list: {
    gap: 12,
  },
  option: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    borderWidth: 1,
    borderColor: "#D1D5DB",
    borderRadius: 8,
    paddingVertical: 14,
    paddingHorizontal: 16,
  },
  icon: {
    fontSize: 20,
  },
  label: {
    fontSize: 16,
    color: "#111827",
  },
});
