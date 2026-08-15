import RNBlobUtil from "react-native-blob-util";
import type { Capsule } from "@commute-capsule/domain";
import { isFullyDownloaded, type StoredCapsule } from "./capsule-store";

/**
 * URIs to queue for playback, in segment-index order. Uses the local
 * downloaded copies only once every segment has one; otherwise streams from
 * the remote URLs so playback still works before (or instead of) a download.
 */
export function playbackQueueUris(capsule: StoredCapsule): string[] {
  if (isFullyDownloaded(capsule)) {
    return capsule.segments
      .map((segment) => capsule.downloadedSegmentUris[segment.index])
      .filter((uri): uri is string => Boolean(uri));
  }
  return capsule.segments.map((segment) => segment.url);
}

function localSegmentPath(capsuleId: string, segmentIndex: number): string {
  return `${RNBlobUtil.fs.dirs.DocumentDir}/capsules/${capsuleId}/segment-${segmentIndex}.mp3`;
}

/**
 * Downloads one segment's audio to the app's document directory and reports
 * the local file:// URI via onComplete. Segments are independent: a failure
 * on one segment does not affect another, and callers may mark each one as
 * it finishes rather than waiting for the whole capsule.
 */
async function downloadSegment(
  capsuleId: string,
  segment: { index: number; url: string },
  onComplete: (segmentIndex: number, localUri: string) => void,
): Promise<void> {
  const path = localSegmentPath(capsuleId, segment.index);
  await RNBlobUtil.config({ path }).fetch("GET", segment.url);
  onComplete(segment.index, `file://${path}`);
}

/** Downloads every segment of a capsule for offline playback. */
export async function downloadCapsule(
  capsule: Capsule,
  onSegmentComplete: (segmentIndex: number, localUri: string) => void,
): Promise<void> {
  await Promise.all(
    capsule.segments.map((segment) => downloadSegment(capsule.id, segment, onSegmentComplete)),
  );
}
