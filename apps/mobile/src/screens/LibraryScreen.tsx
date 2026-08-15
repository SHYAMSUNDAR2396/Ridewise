import React, { useMemo, useState } from "react";
import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { FlatList, Pressable, SafeAreaView, StyleSheet, Text, View } from "react-native";
import {
  isFullyDownloaded,
  useCapsuleStore,
  type StoredCapsule,
} from "../features/capsules/capsule-store";
import type { RootStackParamList } from "../navigation/RootNavigator";

type LibraryTab = "Recent" | "Saved" | "Downloaded";
const TABS: LibraryTab[] = ["Recent", "Saved", "Downloaded"];

function formatDuration(totalSeconds: number): string {
  const minutes = Math.max(1, Math.round(totalSeconds / 60));
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return remainder === 0 ? `${hours} hr` : `${hours} hr ${remainder} min`;
}

/**
 * The Library screen (`library_recent_saved` in the Stitch export):
 * segmented Recent/Saved/Downloaded tabs over a bordered row list. Each row
 * shows title, category/duration/language metadata, an offline indicator
 * only when every segment is downloaded, and a thin progress bar when the
 * capsule has been partially listened to.
 */
export function LibraryScreen(): React.JSX.Element {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const capsules = useCapsuleStore((state) => state.capsules);
  const [tab, setTab] = useState<LibraryTab>("Recent");

  const visibleCapsules = useMemo(() => {
    if (tab === "Saved") return capsules.filter((item) => item.saved);
    if (tab === "Downloaded") return capsules.filter((item) => isFullyDownloaded(item));
    return capsules;
  }, [capsules, tab]);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.tabRow}>
        {TABS.map((label) => {
          const active = tab === label;
          return (
            <Pressable
              key={label}
              accessibilityRole="tab"
              accessibilityLabel={label}
              accessibilityState={{ selected: active }}
              style={[styles.tab, active && styles.tabActive]}
              onPress={() => setTab(label)}
            >
              <Text style={[styles.tabText, active && styles.tabTextActive]}>{label}</Text>
            </Pressable>
          );
        })}
      </View>

      <FlatList
        style={styles.list}
        data={visibleCapsules}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <LibraryRow
            capsule={item}
            onPress={() => navigation.navigate("Player", { capsule: item })}
          />
        )}
      />
    </SafeAreaView>
  );
}

function LibraryRow({
  capsule,
  onPress,
}: {
  capsule: StoredCapsule;
  onPress: () => void;
}): React.JSX.Element {
  const downloaded = isFullyDownloaded(capsule);
  const progressRatio =
    capsule.audioSeconds > 0 ? capsule.progressSeconds / capsule.audioSeconds : 0;
  const showProgress = progressRatio > 0 && progressRatio < 1;

  return (
    <Pressable accessibilityRole="button" style={styles.row} onPress={onPress}>
      <View style={styles.rowIcon} />
      <View style={styles.rowBody}>
        <Text style={styles.rowTitle} numberOfLines={1}>
          {capsule.title}
        </Text>
        <View style={styles.rowMeta}>
          <Text style={styles.rowMetaText}>{capsule.topic}</Text>
          <Text style={styles.rowMetaDot}>•</Text>
          <Text style={styles.rowMetaText}>{formatDuration(capsule.audioSeconds)}</Text>
          <Text style={styles.rowMetaDot}>•</Text>
          <Text style={styles.rowMetaText}>
            {capsule.language === "en-IN" ? "EN" : capsule.language}
          </Text>
          {downloaded ? (
            <Text accessibilityLabel="Downloaded offline" style={styles.offlinePin}>
              ⬇
            </Text>
          ) : null}
        </View>
        {showProgress ? (
          <View style={styles.progressTrack}>
            <View
              style={[styles.progressFill, { width: `${Math.round(progressRatio * 100)}%` }]}
            />
          </View>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f9f9f9",
  },
  tabRow: {
    flexDirection: "row",
    gap: 8,
    padding: 4,
    marginHorizontal: 24,
    marginTop: 16,
    borderRadius: 8,
    backgroundColor: "#e2e2e2",
  },
  tab: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 6,
    alignItems: "center",
  },
  tabActive: {
    backgroundColor: "#f9f9f9",
    borderWidth: 1,
    borderColor: "#c3c6d7",
  },
  tabText: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    color: "#434655",
  },
  tabTextActive: {
    color: "#1a1c1c",
  },
  list: {
    marginTop: 16,
    marginHorizontal: 24,
    borderWidth: 1,
    borderColor: "#c3c6d7",
    borderRadius: 12,
    backgroundColor: "#f9f9f9",
  },
  row: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 16,
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#e8e8e8",
  },
  rowIcon: {
    width: 48,
    height: 48,
    borderRadius: 12,
    backgroundColor: "#e8e8e8",
  },
  rowBody: {
    flex: 1,
    gap: 4,
  },
  rowTitle: {
    fontFamily: "Newsreader",
    fontSize: 24,
    fontWeight: "500",
    color: "#1a1c1c",
  },
  rowMeta: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  rowMetaText: {
    fontFamily: "Manrope",
    fontSize: 12,
    fontWeight: "700",
    color: "#434655",
  },
  rowMetaDot: {
    fontSize: 4,
    color: "#c3c6d7",
  },
  offlinePin: {
    fontSize: 12,
    color: "#434655",
  },
  progressTrack: {
    marginTop: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: "#e8e8e8",
    overflow: "hidden",
  },
  progressFill: {
    height: 4,
    borderRadius: 2,
    backgroundColor: "#004ac6",
  },
});
