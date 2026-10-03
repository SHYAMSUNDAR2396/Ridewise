import React, { useMemo, useState } from "react";
import { FlatList, Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Artwork } from "../components/Artwork";
import { Chip } from "../components/Chip";
import { EmptyState } from "../components/EmptyState";
import { Icon } from "../components/Icon";
import {
  isFullyDownloaded,
  useCapsuleStore,
  type StoredCapsule,
} from "../features/capsules/capsule-store";
import { deleteCapsuleFiles } from "../features/capsules/download";
import { useAppNavigation } from "../navigation/useAppNavigation";
import { colors, fonts } from "../theme";

type LibraryTab = "Recent" | "Saved" | "Downloaded";
const TABS: LibraryTab[] = ["Recent", "Saved", "Downloaded"];

const EMPTY_STATE_COPY: Record<LibraryTab, { title: string; message: string }> = {
  Recent: {
    title: "No capsules yet",
    message: "Capsules you create will show up here.",
  },
  Saved: {
    title: "No saved capsules",
    message: "Save a capsule from the player to find it here.",
  },
  Downloaded: {
    title: "No downloads yet",
    message: "Download a capsule for offline listening.",
  },
};

function formatDuration(totalSeconds: number): string {
  const minutes = Math.max(1, Math.round(totalSeconds / 60));
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return remainder === 0 ? `${hours} hr` : `${hours} hr ${remainder} min`;
}

/** Library: Recent, Saved and Downloaded capsules as a flat list with artwork. */
export function LibraryScreen(): React.JSX.Element {
  const navigation = useAppNavigation();
  const capsules = useCapsuleStore((state) => state.capsules);
  const removeCapsule = useCapsuleStore((state) => state.remove);
  const [tab, setTab] = useState<LibraryTab>("Recent");

  // Removes a capsule from the local library and deletes any downloaded segment
  // files. File deletion is best-effort: the entry is removed either way so a
  // stuck file never blocks removing the row.
  async function handleDelete(id: string): Promise<void> {
    await deleteCapsuleFiles(id).catch(() => undefined);
    removeCapsule(id);
  }

  const visibleCapsules = useMemo(() => {
    if (tab === "Saved") return capsules.filter((item) => item.saved);
    if (tab === "Downloaded") return capsules.filter((item) => isFullyDownloaded(item));
    return capsules;
  }, [capsules, tab]);

  return (
    <SafeAreaView style={styles.container} edges={["top"]}>
      <FlatList
        data={visibleCapsules}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        ListHeaderComponent={
          <View style={styles.header}>
            <Text style={styles.title}>Library</Text>
            <View style={styles.tabRow}>
              {TABS.map((label) => (
                <Chip
                  key={label}
                  role="tab"
                  label={label}
                  selected={tab === label}
                  onPress={() => setTab(label)}
                />
              ))}
            </View>
          </View>
        }
        renderItem={({ item }) => (
          <LibraryRow
            capsule={item}
            onPress={() => navigation.navigate("Player", { capsule: item })}
            onDelete={() => handleDelete(item.id)}
          />
        )}
        ListEmptyComponent={
          <EmptyState title={EMPTY_STATE_COPY[tab].title} message={EMPTY_STATE_COPY[tab].message} />
        }
      />
    </SafeAreaView>
  );
}

function LibraryRow({
  capsule,
  onPress,
  onDelete,
}: {
  capsule: StoredCapsule;
  onPress: () => void;
  onDelete: () => void;
}): React.JSX.Element {
  const downloaded = isFullyDownloaded(capsule);
  const progressRatio =
    capsule.audioSeconds > 0 ? capsule.progressSeconds / capsule.audioSeconds : 0;
  const showProgress = progressRatio > 0 && progressRatio < 1;

  return (
    <Pressable accessibilityRole="button" style={styles.row} onPress={onPress}>
      <Artwork seed={capsule.id} size={52} radius={9} />
      <View style={styles.rowBody}>
        <Text style={styles.rowTitle} numberOfLines={1}>
          {capsule.title}
        </Text>
        <View style={styles.rowMeta}>
          <Text style={styles.rowMetaText}>{capsule.topic}</Text>
          <Text style={styles.rowMetaText}>{formatDuration(capsule.audioSeconds)}</Text>
          <Text style={styles.rowMetaText}>
            {capsule.language === "en-IN" ? "EN" : capsule.language}
          </Text>
          {downloaded ? (
            <View accessibilityLabel="Downloaded offline" accessible>
              <Icon name="check" size={16} color={colors.accent} />
            </View>
          ) : null}
        </View>
        {showProgress ? (
          <View style={styles.progressTrack}>
            <View style={[styles.progressFill, { width: `${Math.round(progressRatio * 100)}%` }]} />
          </View>
        ) : null}
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Delete ${capsule.title}`}
        style={styles.rowDelete}
        onPress={(event) => {
          event.stopPropagation();
          onDelete();
        }}
      >
        <Icon name="close" size={18} color={colors.textMuted} />
      </Pressable>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  listContent: { paddingHorizontal: 20, paddingBottom: 24 },
  header: { gap: 12, paddingTop: 12, paddingBottom: 8 },
  title: {
    fontFamily: fonts.serif,
    fontSize: 38,
    fontWeight: "700",
    letterSpacing: -0.5,
    color: colors.text,
  },
  tabRow: { flexDirection: "row", gap: 8 },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    minHeight: 68,
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: colors.line,
  },
  rowBody: { flex: 1, gap: 2 },
  rowTitle: { fontSize: 15, fontWeight: "700", color: colors.text },
  rowMeta: { flexDirection: "row", alignItems: "center", gap: 10 },
  rowMetaText: { fontSize: 13, color: colors.textMuted },
  rowDelete: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  progressTrack: { marginTop: 4, height: 3, borderRadius: 2, backgroundColor: colors.line, overflow: "hidden" },
  progressFill: { height: 3, borderRadius: 2, backgroundColor: colors.accent },
});
