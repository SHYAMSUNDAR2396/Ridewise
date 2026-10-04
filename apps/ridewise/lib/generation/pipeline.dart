import '../domain/models.dart';
import '../domain/text.dart';
import 'types.dart';

// Short segments keep each speech call quick, so playback can begin early and a
// failed segment is cheap to retry.
const _maxSegmentChars = 600;
const _shorteningFactor = 0.85;

int _wordsPerMinute(CapsuleLanguage language) =>
    language == CapsuleLanguage.hiIN ? 130 : 150;

class PipelineDeps {
  const PipelineDeps({
    required this.script,
    required this.speech,
    required this.segmentPath,
    required this.newId,
    required this.now,
    required this.cleanup,
    this.onProgress,
    this.retryDelay = const Duration(milliseconds: 200),
  });

  final ScriptWriter script;
  final SpeechEngine speech;
  final String Function(String capsuleId, int index) segmentPath;
  final String Function() newId;
  final DateTime Function() now;

  /// Deletes any audio already written for a capsule.
  final Future<void> Function(String capsuleId) cleanup;
  final ProgressCallback? onProgress;
  final Duration retryDelay;
}

/// Writes a script, speaks it segment by segment, and returns a capsule that
/// finishes before the trip does. Published audio never exceeds the target: on
/// overrun it makes one shorter attempt, then fails with capsuleTooLong
/// instead of cutting audio mid-sentence.
Future<Capsule> createCapsuleOnDevice(
  CreateCapsuleRequest request,
  PipelineDeps deps,
) async {
  final tripSeconds = request.trip.tripSeconds;
  if (tripSeconds == null || tripSeconds <= 0) {
    throw GenerationException(
      CapsuleErrorCode.routeUnavailable,
      'Set a trip time to continue.',
    );
  }

  final targetSeconds = calculateTargetSeconds(tripSeconds);
  final id = deps.newId();
  var targetWords = (targetSeconds / 60 * _wordsPerMinute(request.language))
      .round();

  for (var attempt = 0; attempt < 2; attempt++) {
    deps.onProgress?.call(
      const GenerationProgress(GenerationPhase.script, 0, 1),
    );
    final Script script;
    try {
      script = await deps.script.write(
        ScriptRequest(
          topic: request.topic,
          style: request.style,
          language: request.language,
          targetWords: targetWords,
        ),
      );
    } catch (_) {
      throw GenerationException(
        CapsuleErrorCode.scriptGenerationFailed,
        "We couldn't write your capsule's script. Please try again.",
      );
    }

    final texts = splitIntoSegments(script.transcript, _maxSegmentChars);
    final segments = <AudioSegment>[];
    var audioSeconds = 0.0;
    var overran = false;

    for (final (index, text) in texts.indexed) {
      deps.onProgress?.call(
        GenerationProgress(GenerationPhase.voice, index, texts.length),
      );
      final path = deps.segmentPath(id, index);
      final ({double durationSeconds}) result;
      try {
        result = await withRetry(
          () => deps.speech.synthesizeToFile(text, path, request.language),
          baseDelay: deps.retryDelay,
        );
      } catch (_) {
        await deps.cleanup(id);
        throw GenerationException(
          CapsuleErrorCode.speechSynthesisFailed,
          "We couldn't record your capsule's audio. Please try again.",
        );
      }

      audioSeconds += result.durationSeconds;
      segments.add(
        AudioSegment(
          index: index,
          url: 'file://$path',
          durationSeconds: result.durationSeconds,
        ),
      );

      // Stop speaking as soon as the audio no longer fits; the rest would be wasted work.
      if (audioSeconds > targetSeconds) {
        overran = true;
        break;
      }
    }

    if (!overran) {
      return Capsule(
        id: id,
        title: script.title,
        topic: request.topic,
        language: request.language,
        targetSeconds: targetSeconds,
        audioSeconds: audioSeconds,
        transcript: script.transcript,
        segments: segments,
        createdAt: deps.now(),
      );
    }

    await deps.cleanup(id);
    targetWords = (targetWords * _shorteningFactor).round();
  }

  throw GenerationException(
    CapsuleErrorCode.capsuleTooLong,
    "This capsule couldn't fit your trip even after shortening. Please try again.",
  );
}
