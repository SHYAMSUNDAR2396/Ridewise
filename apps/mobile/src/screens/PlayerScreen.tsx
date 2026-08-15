import React, { useEffect, useState } from "react";
import { useNavigation, useRoute } from "@react-navigation/native";
import type { RouteProp } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import {
  Modal,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { CapsulePlayer } from "../features/capsules/player";
import { downloadCapsule } from "../features/capsules/download";
import { isFullyDownloaded, useCapsuleStore } from "../features/capsules/capsule-store";
import type { RootStackParamList } from "../navigation/RootNavigator";

type PlayerScreenRouteProp = RouteProp<RootStackParamList, "Player">;

const LANGUAGE_LABELS: Record<string, string> = { "en-IN": "English" };

/**
 * The Player screen (`player_simplified_flow` in the Stitch export): a
 * minimal header, artwork card, centered metadata, the CapsulePlayer's
 * scrubber and transport controls, a Transcript/Save/Download action row,
 * and the transcript as an in-player bottom sheet -- not a separate route.
 *
 * No playback-speed control, no regenerate action: both are out of scope.
 */
export function PlayerScreen(): React.JSX.Element {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute<PlayerScreenRouteProp>();
  const { capsule } = route.params;

  const upsert = useCapsuleStore((state) => state.upsert);
  const setProgress = useCapsuleStore((state) => state.setProgress);
  const toggleSaved = useCapsuleStore((state) => state.toggleSaved);
  const markSegmentDownloaded = useCapsuleStore((state) => state.markSegmentDownloaded);
  const stored = useCapsuleStore((state) => state.capsules.find((item) => item.id === capsule.id));

  const [transcriptOpen, setTranscriptOpen] = useState(false);
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    upsert(capsule);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only re-upsert if a different capsule is opened
  }, [capsule.id]);

  const saved = stored?.saved ?? false;
  const downloaded = stored ? isFullyDownloaded(stored) : false;
  const initialPositionSeconds = stored?.progressSeconds ?? 0;

  function handleProgress(seconds: number): void {
    setProgress(capsule.id, seconds);
  }

  async function handleDownload(): Promise<void> {
    if (downloading || downloaded) return;
    setDownloading(true);
    try {
      await downloadCapsule(capsule, (segmentIndex, uri) => {
        markSegmentDownloaded(capsule.id, segmentIndex, uri);
      });
    } finally {
      setDownloading(false);
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Collapse player"
          style={styles.headerButton}
          onPress={() => navigation.goBack()}
        >
          <Text style={styles.headerIcon}>⌄</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="More options"
          style={styles.headerButton}
        >
          <Text style={styles.headerIcon}>⋮</Text>
        </Pressable>
      </View>

      <View style={styles.artwork} />

      <View style={styles.metadata}>
        <Text style={styles.eyebrow}>
          {capsule.topic} • {LANGUAGE_LABELS[capsule.language] ?? capsule.language}
        </Text>
        <Text style={styles.title}>{capsule.title}</Text>
        <Text style={styles.subtitle}>Narrated by Ridewise AI</Text>
      </View>

      <CapsulePlayer
        capsule={capsule}
        initialPositionSeconds={initialPositionSeconds}
        onProgress={handleProgress}
      />

      <View style={styles.actionsRow}>
        <Pressable
          accessibilityRole="button"
          style={styles.action}
          onPress={() => setTranscriptOpen(true)}
        >
          <Text style={styles.actionText}>Transcript</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          style={styles.action}
          onPress={() => toggleSaved(capsule.id)}
        >
          <Text style={styles.actionText}>{saved ? "Saved" : "Save"}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          style={styles.action}
          disabled={downloading || downloaded}
          onPress={handleDownload}
        >
          <Text style={styles.actionText}>
            {downloaded ? "Downloaded" : downloading ? "Downloading…" : "Download"}
          </Text>
        </Pressable>
      </View>

      <Modal
        visible={transcriptOpen}
        animationType="slide"
        transparent
        onRequestClose={() => setTranscriptOpen(false)}
      >
        <Pressable
          accessibilityLabel="Close transcript"
          style={styles.backdrop}
          onPress={() => setTranscriptOpen(false)}
        />
        <View style={styles.sheet}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Collapse transcript"
            style={styles.dragHandleArea}
            onPress={() => setTranscriptOpen(false)}
          >
            <View style={styles.dragHandle} />
          </Pressable>
          <View style={styles.sheetHeader}>
            <Text style={styles.sheetTitle}>Live Transcript</Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Close transcript"
              onPress={() => setTranscriptOpen(false)}
            >
              <Text style={styles.headerIcon}>×</Text>
            </Pressable>
          </View>
          <ScrollView style={styles.transcriptBody}>
            <Text style={styles.transcriptText}>{capsule.transcript}</Text>
          </ScrollView>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f9f9f9",
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 24,
    height: 64,
  },
  headerButton: {
    padding: 8,
  },
  headerIcon: {
    fontSize: 24,
    color: "#434655",
  },
  artwork: {
    alignSelf: "center",
    width: "80%",
    maxWidth: 320,
    aspectRatio: 1,
    borderRadius: 24,
    backgroundColor: "#f3f3f3",
    borderWidth: 1,
    borderColor: "rgba(195, 198, 215, 0.5)",
    marginVertical: 16,
  },
  metadata: {
    alignItems: "center",
    paddingHorizontal: 24,
    marginBottom: 32,
    gap: 4,
  },
  eyebrow: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 1,
    textTransform: "uppercase",
    color: "#2563eb",
    marginBottom: 8,
  },
  title: {
    fontFamily: "Newsreader",
    fontSize: 32,
    fontWeight: "600",
    color: "#1a1c1c",
    textAlign: "center",
  },
  subtitle: {
    fontFamily: "Manrope",
    fontSize: 18,
    color: "#434655",
    opacity: 0.8,
  },
  actionsRow: {
    flexDirection: "row",
    justifyContent: "space-evenly",
    alignItems: "center",
    paddingVertical: 24,
    paddingHorizontal: 24,
    marginTop: 24,
  },
  action: {
    alignItems: "center",
    gap: 6,
    width: 72,
  },
  actionText: {
    fontFamily: "Manrope",
    fontSize: 11,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    color: "#434655",
  },
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(26, 28, 28, 0.4)",
  },
  sheet: {
    height: "75%",
    backgroundColor: "#2f3131",
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
  },
  dragHandleArea: {
    alignItems: "center",
    paddingTop: 20,
    paddingBottom: 12,
  },
  dragHandle: {
    width: 48,
    height: 6,
    borderRadius: 3,
    backgroundColor: "rgba(115, 118, 134, 0.5)",
  },
  sheetHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 24,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(115, 118, 134, 0.2)",
  },
  sheetTitle: {
    fontFamily: "Newsreader",
    fontSize: 24,
    fontWeight: "500",
    color: "#f0f1f1",
  },
  transcriptBody: {
    flex: 1,
    paddingHorizontal: 24,
    paddingVertical: 24,
  },
  transcriptText: {
    fontFamily: "Manrope",
    fontSize: 18,
    lineHeight: 28,
    color: "#f0f1f1",
    opacity: 0.8,
  },
});
