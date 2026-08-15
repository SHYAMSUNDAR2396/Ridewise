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

function localCapsuleDir(capsuleId: string): string {
  return `${RNBlobUtil.fs.dirs.DocumentDir}/capsules/${capsuleId}`;
}

function localSegmentPath(capsuleId: string, segmentIndex: number): string {
  return `${localCapsuleDir(capsuleId)}/segment-${segmentIndex}.mp3`;
}

/** Deletes a capsule's locally-downloaded segment files, if any exist. */
export async function deleteCapsuleFiles(capsuleId: string): Promise<void> {
  const dir = localCapsuleDir(capsuleId);
  if (await RNBlobUtil.fs.exists(dir)) {
    await RNBlobUtil.fs.unlink(dir);
  }
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

/**
 * Downloads every segment of a capsule for offline playback. Segments are
 * independent, so one segment's failure never stops the others from
 * completing and registering via onSegmentComplete. Throws if at least one
 * segment failed, after every segment has settled, so the caller can surface
 * a single error while the successful segments remain downloaded.
 */
export async function downloadCapsule(
  capsule: Capsule,
  onSegmentComplete: (segmentIndex: number, localUri: string) => void,
): Promise<void> {
  const results = await Promise.allSettled(
    capsule.segments.map((segment) => downloadSegment(capsule.id, segment, onSegmentComplete)),
  );
  const failures = results.filter(
    (result): result is PromiseRejectedResult => result.status === "rejected",
  );
  if (failures.length > 0) {
    throw new Error(
      `${failures.length} of ${capsule.segments.length} segment download(s) failed`,
    );
  }
}
