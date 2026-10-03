import React, { useEffect, useState } from "react";
import { useRoute } from "@react-navigation/native";
import type { RouteProp } from "@react-navigation/native";
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Artwork, GradientFill } from "../components/Artwork";
import { Icon } from "../components/Icon";
import { RetryNotice } from "../components/RetryNotice";
import { isFullyDownloaded, useCapsuleStore } from "../features/capsules/capsule-store";
import { downloadCapsule } from "../features/capsules/download";
import { useNowPlaying } from "../features/capsules/now-playing";
import { CapsulePlayer } from "../features/capsules/player";
import { useAppNavigation } from "../navigation/useAppNavigation";
import type { RootStackParamList } from "../navigation/RootNavigator";
import { colors, fonts } from "../theme";

type PlayerScreenRouteProp = RouteProp<RootStackParamList, "Player">;

const LANGUAGE_LABELS: Record<string, string> = { "en-IN": "English" };

/**
 * Now Playing: artwork, title, the scrubber and transport controls, and a
 * Transcript / Save / Download action row. The transcript opens as a sheet.
 * No playback-speed control and no regenerate action: both are out of scope.
 */
export function PlayerScreen(): React.JSX.Element {
  const navigation = useAppNavigation();
  const route = useRoute<PlayerScreenRouteProp>();
  const { capsule } = route.params;

  const upsert = useCapsuleStore((state) => state.upsert);
  const setProgress = useCapsuleStore((state) => state.setProgress);
  const toggleSaved = useCapsuleStore((state) => state.toggleSaved);
  const markSegmentDownloaded = useCapsuleStore((state) => state.markSegmentDownloaded);
  const stored = useCapsuleStore((state) => state.capsules.find((item) => item.id === capsule.id));
  const setNowPlaying = useNowPlaying((state) => state.setCapsuleId);

  const [transcriptOpen, setTranscriptOpen] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [downloadError, setDownloadError] = useState(false);
  const [audioUnavailable, setAudioUnavailable] = useState(false);
  const [playerRetryToken, setPlayerRetryToken] = useState(0);

  useEffect(() => {
    upsert(capsule);
    setNowPlaying(capsule.id);
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
    setDownloadError(false);
    try {
      await downloadCapsule(capsule, (segmentIndex, uri) => {
        markSegmentDownloaded(capsule.id, segmentIndex, uri);
      });
    } catch {
      // Segments download independently (see download.ts): any that succeeded are
      // already marked above. This only surfaces that at least one failed.
      setDownloadError(true);
    } finally {
      setDownloading(false);
    }
  }

  return (
    <View style={styles.root}>
      <GradientFill from={colors.playerTop} to={colors.playerBottom} id="player" />
      <SafeAreaView style={styles.container}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Collapse player"
          style={styles.grabberArea}
          onPress={() => navigation.goBack()}
        >
          <View style={styles.grabber} />
        </Pressable>

        <View style={styles.artwork}>
          <Artwork seed={capsule.id} size={300} radius={18} />
        </View>

        <View style={styles.metadata}>
          <Text style={styles.title} numberOfLines={2}>
            {capsule.title}
          </Text>
          <Text style={styles.subtitle}>
            {capsule.topic}, {LANGUAGE_LABELS[capsule.language] ?? capsule.language}
          </Text>
        </View>

        {audioUnavailable ? (
          <View style={styles.audioUnavailable}>
            <RetryNotice
              headline="Audio unavailable right now."
              message="We couldn't load this capsule's audio. Check your connection and try again."
              actionLabel="Retry"
              onRetry={() => {
                setAudioUnavailable(false);
                setPlayerRetryToken((token) => token + 1);
              }}
              icon="alert"
            />
          </View>
        ) : (
          <CapsulePlayer
            key={playerRetryToken}
            capsule={capsule}
            initialPositionSeconds={initialPositionSeconds}
            onProgress={handleProgress}
            onPlaybackError={() => setAudioUnavailable(true)}
          />
        )}

        <View style={styles.actionsRow}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Transcript"
            style={styles.action}
            onPress={() => setTranscriptOpen(true)}
          >
            <Icon name="transcript" size={24} color={colors.onPlayer} />
            <Text style={styles.actionText}>Transcript</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={saved ? "Saved" : "Save"}
            style={styles.action}
            onPress={() => toggleSaved(capsule.id)}
          >
            <Icon name="bookmark" size={24} color={colors.onPlayer} />
            <Text style={styles.actionText}>{saved ? "Saved" : "Save"}</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={downloaded ? "Downloaded" : downloading ? "Downloading" : "Download"}
            style={styles.action}
            disabled={downloading || downloaded}
            onPress={handleDownload}
          >
            <Icon name={downloaded ? "check" : "download"} size={24} color={colors.onPlayer} />
            <Text style={styles.actionText}>
              {downloaded ? "Downloaded" : downloading ? "Downloading…" : "Download"}
            </Text>
          </Pressable>
        </View>

        {downloadError ? (
          <Text style={styles.downloadErrorText}>
            Some segments couldn't download. The rest are saved offline. Try again for the rest.
          </Text>
        ) : null}
      </SafeAreaView>

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
          <View style={styles.sheetHeader}>
            <Text style={styles.sheetTitle}>Transcript</Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Collapse transcript"
              style={styles.sheetClose}
              onPress={() => setTranscriptOpen(false)}
            >
              <Icon name="close" size={22} color={colors.text} />
            </Pressable>
          </View>
          <ScrollView style={styles.transcriptBody}>
            <Text style={styles.transcriptText}>{capsule.transcript}</Text>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.playerMid, overflow: "hidden" },
  container: { flex: 1, gap: 16 },
  grabberArea: { alignSelf: "center", width: 80, height: 44, alignItems: "center", justifyContent: "center" },
  grabber: { width: 40, height: 5, borderRadius: 3, backgroundColor: "rgba(255,255,255,0.45)" },
  artwork: {
    alignSelf: "center",
    shadowColor: "#000000",
    shadowOpacity: 0.4,
    shadowRadius: 22,
    shadowOffset: { width: 0, height: 12 },
    elevation: 12,
  },
  metadata: { paddingHorizontal: 32, gap: 2 },
  title: { fontFamily: fonts.serif, fontSize: 27, fontWeight: "700", letterSpacing: -0.3, color: colors.onPlayer },
  subtitle: { fontSize: 15, fontWeight: "600", color: colors.onPlayerMuted },
  audioUnavailable: { paddingHorizontal: 24 },
  actionsRow: {
    flexDirection: "row",
    justifyContent: "space-around",
    paddingHorizontal: 24,
    marginTop: "auto",
    paddingBottom: 16,
  },
  action: { minWidth: 72, minHeight: 56, alignItems: "center", justifyContent: "center", gap: 4 },
  actionText: { fontSize: 12, fontWeight: "700", color: colors.onPlayer },
  downloadErrorText: { fontSize: 13, color: colors.onPlayerMuted, textAlign: "center", paddingHorizontal: 32 },
  backdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.5)" },
  sheet: {
    maxHeight: "70%",
    backgroundColor: colors.bg,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 20,
  },
  sheetHeader: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: 8 },
  sheetTitle: { fontFamily: fonts.serif, fontSize: 26, fontWeight: "700", color: colors.text },
  sheetClose: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  transcriptBody: { flexGrow: 0 },
  transcriptText: { fontSize: 17, lineHeight: 28, color: colors.text, paddingBottom: 24 },
});
