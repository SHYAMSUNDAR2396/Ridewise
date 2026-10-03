import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import type { BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Icon, type IconName } from "../components/Icon";
import { MiniPlayer } from "../components/MiniPlayer";
import { colors } from "../theme";

const TAB_ICONS: Record<string, IconName> = {
  ListenNow: "headphones",
  Plan: "route",
  Library: "library",
};

const TAB_LABELS: Record<string, string> = {
  ListenNow: "Listen Now",
  Plan: "Plan",
  Library: "Library",
};

/** Tab bar with the mini player docked above it, like Apple Music. */
export function TabBar({ state, navigation }: BottomTabBarProps): React.JSX.Element {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.wrap, { paddingBottom: Math.max(insets.bottom, 8) }]}>
      <MiniPlayer
        onOpen={(capsule) =>
          (navigation as unknown as { navigate: (name: string, params: unknown) => void }).navigate(
            "Player",
            { capsule },
          )
        }
      />
      <View style={styles.row}>
        {state.routes.map((route, index) => {
          const focused = state.index === index;
          const color = focused ? colors.accent : colors.textMuted;
          const label = TAB_LABELS[route.name] ?? route.name;
          return (
            <Pressable
              key={route.key}
              accessibilityRole="tab"
              accessibilityLabel={label}
              accessibilityState={{ selected: focused }}
              style={styles.tab}
              onPress={() => {
                const event = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
                if (!focused && !event.defaultPrevented) navigation.navigate(route.name);
              }}
            >
              <Icon name={TAB_ICONS[route.name] ?? "headphones"} color={color} />
              <Text style={[styles.label, { color }, focused && styles.labelFocused]}>{label}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    backgroundColor: colors.bg,
    borderTopWidth: 1,
    borderTopColor: colors.line,
    paddingTop: 8,
  },
  row: { flexDirection: "row" },
  tab: { flex: 1, minHeight: 48, alignItems: "center", justifyContent: "center", gap: 3 },
  label: { fontSize: 11, fontWeight: "700" },
  labelFocused: { fontWeight: "800" },
});
