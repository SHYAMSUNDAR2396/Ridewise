import 'dart:async';
import 'dart:math';

import '../domain/models.dart';
import '../domain/text.dart';
import 'types.dart';

// Short segments keep each speech call quick, so the first part can play early and a
// failed segment is cheap to retry.
const _maxSegmentChars = 600;
const _minSectionWords = 40;
const _unfinishedNotice = 'We could not finish the rest of this capsule.';

int _wordsPerMinute(CapsuleLanguage language) =>
    language == CapsuleLanguage.hiIN ? 130 : 150;

int _wordCount(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

class PipelineDeps {
  const PipelineDeps({
    required this.script,
    required this.speech,
    required this.segmentPath,
    required this.newId,
    required this.now,
    required this.cleanup,
    required this.deleteFile,
    this.retryDelay = const Duration(milliseconds: 200),
  });

  final ScriptWriter script;
  final SpeechEngine speech;
  final String Function(String capsuleId, int index) segmentPath;
  final String Function() newId;
  final DateTime Function() now;

  /// Deletes every audio file already written for a capsule.
  final Future<void> Function(String capsuleId) cleanup;

  /// Deletes one audio file (a segment dropped for not fitting).
  final Future<void> Function(String path) deleteFile;
  final Duration retryDelay;
}

GenerationException _asScriptFailure(Object error) =>
    error is GenerationException
    ? error
    : GenerationException(
        CapsuleErrorCode.scriptGenerationFailed,
        "We couldn't write your capsule's script. Please try again.",
      );

/// Makes a capsule part by part, so the first part can play while later parts are made.
///
/// Per section: the text is written (the next section is already being written while this
/// one is spoken), split into segments, and each segment is spoken and emitted as a growing
/// capsule. The pace is re-measured after every segment (seconds of audio per word), and each
/// next section's word budget is the time still left divided over the sections still to
/// come, so the capsule lands near the trip time instead of trusting a words-per-minute guess.
///
/// Published audio never exceeds the target: a segment that would push the total past it is
/// dropped and the capsule ends there. Audio shorter than the target is not padded.
///
/// Failure before any segment exists throws a [GenerationException] and cleans up. After the
/// first segment, a failure ends the stream with a complete update carrying a notice.
Stream<CapsuleUpdate> createCapsuleOnDevice(
  CreateCapsuleRequest request,
  PipelineDeps deps,
) async* {
  final tripSeconds = request.trip.tripSeconds;
  if (tripSeconds == null || tripSeconds <= 0) {
    throw GenerationException(
      CapsuleErrorCode.routeUnavailable,
      'Set a trip time to continue.',
    );
  }

  final targetSeconds = calculateTargetSeconds(tripSeconds);
  final id = deps.newId();
  final createdAt = deps.now();
  final wpm = _wordsPerMinute(request.language);
  var secondsPerWord = 60 / wpm;
  final scriptRequest = ScriptRequest(
    topic: request.topic,
    style: request.style,
    language: request.language,
    targetWords: (targetSeconds / 60 * wpm).round(),
  );

  yield const CapsuleUpdate(
    progress: GenerationProgress(GenerationPhase.script, 0, 1),
  );

  final ScriptOutline outline;
  try {
    outline = await deps.script.outline(scriptRequest);
  } catch (error) {
    await deps.cleanup(id);
    throw _asScriptFailure(error);
  }
  final total = outline.headings.length;

  final segments = <AudioSegment>[];
  final spokenTexts = <String>[];
  var audioSeconds = 0.0;
  var wordsSpoken = 0;
  var estimatedTotal = 0;

  Capsule snapshot({required bool complete}) => Capsule(
    id: id,
    title: outline.title,
    topic: request.topic,
    language: request.language,
    targetSeconds: targetSeconds,
    audioSeconds: audioSeconds,
    transcript: spokenTexts.join(' '),
    segments: List.of(segments),
    createdAt: createdAt,
    complete: complete,
  );

  Future<String> writeSection(int index, int words, String previous) =>
      deps.script.writeSection(
        request: scriptRequest,
        outline: outline,
        index: index,
        words: words,
        previousText: previous,
      );

  int wordsFor(double secondsLeft, int sectionsLeft) => max(
    _minSectionWords,
    (secondsLeft / sectionsLeft / secondsPerWord).round(),
  );

  GenerationException? failure;
  var overran = false;
  Future<String> current = writeSection(
    0,
    wordsFor(targetSeconds.toDouble(), total),
    '',
  );

  sections:
  for (var i = 0; i < total; i++) {
    final String text;
    try {
      text = await current;
    } catch (error) {
      failure = _asScriptFailure(error);
      break;
    }

    // Start writing the next section now, while this one is spoken. Its budget assumes this
    // section will take its words at the pace measured so far.
    if (i + 1 < total) {
      final estimatedAudio = _wordCount(text) * secondsPerWord;
      final next = writeSection(
        i + 1,
        wordsFor(targetSeconds - audioSeconds - estimatedAudio, total - i - 1),
        text,
      );
      // An unobserved failure here must not crash the app; it is surfaced where it is awaited.
      unawaited(next.then<void>((_) {}, onError: (Object _) {}));
      current = next;
    }

    final texts = splitIntoSegments(text, _maxSegmentChars);
    for (final (j, segmentText) in texts.indexed) {
      // Remaining sections are assumed to split into as many segments as this one.
      estimatedTotal = max(
        estimatedTotal,
        segments.length + (texts.length - j) + (total - i - 1) * texts.length,
      );
      yield CapsuleUpdate(
        progress: GenerationProgress(
          GenerationPhase.voice,
          segments.length,
          estimatedTotal,
        ),
      );

      final path = deps.segmentPath(id, segments.length);
      final ({double durationSeconds}) result;
      try {
        result = await withRetry(
          () =>
              deps.speech.synthesizeToFile(segmentText, path, request.language),
          baseDelay: deps.retryDelay,
        );
      } catch (_) {
        failure = GenerationException(
          CapsuleErrorCode.speechSynthesisFailed,
          "We couldn't record your capsule's audio. Please try again.",
        );
        break sections;
      }

      if (audioSeconds + result.durationSeconds > targetSeconds) {
        await deps.deleteFile(path);
        overran = true;
        break sections;
      }

      audioSeconds += result.durationSeconds;
      wordsSpoken += _wordCount(segmentText);
      secondsPerWord = audioSeconds / wordsSpoken;
      segments.add(
        AudioSegment(
          index: segments.length,
          url: 'file://$path',
          durationSeconds: result.durationSeconds,
        ),
      );
      spokenTexts.add(segmentText);
      yield CapsuleUpdate(capsule: snapshot(complete: false));
    }
  }

  if (segments.isEmpty) {
    await deps.cleanup(id);
    throw failure ??
        (overran
            ? GenerationException(
                CapsuleErrorCode.capsuleTooLong,
                "This capsule couldn't fit your trip. Please try a longer trip time.",
              )
            : _asScriptFailure('no audio'));
  }

  yield CapsuleUpdate(
    capsule: snapshot(complete: true),
    complete: true,
    notice: failure == null ? null : _unfinishedNotice,
  );
}
