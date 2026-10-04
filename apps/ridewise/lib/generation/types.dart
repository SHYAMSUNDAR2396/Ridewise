import '../domain/models.dart';

/// A local language model. Implemented over llamadart on device and by fakes in tests.
/// [system] is an optional fixed instruction (the host persona) sent before the prompt.
abstract interface class TextModel {
  Future<String> complete(
    String prompt, {
    required int maxTokens,
    String? system,
  });
}

/// A local speech engine that writes one WAV file per call.
abstract interface class SpeechEngine {
  Future<({double durationSeconds})> synthesizeToFile(
    String text,
    String filePath,
    CapsuleLanguage language,
  );
}

class ScriptRequest {
  const ScriptRequest({
    required this.topic,
    required this.style,
    required this.language,
    required this.targetWords,
  });
  final String topic;
  final ListeningStyle style;
  final CapsuleLanguage language;

  /// Words for the whole talk. Used to decide how many sections to plan.
  final int targetWords;
}

/// The plan for a talk: a title, an opening hook, one heading per section with its key
/// points, and the one thing the listener should remember.
class ScriptOutline {
  const ScriptOutline({
    required this.title,
    required this.headings,
    this.hook = '',
    this.takeaway = '',
    this.points = const [],
  });
  final String title;
  final List<String> headings;

  /// One surprising fact or question to open the talk with. Empty when the model gave none.
  final String hook;

  /// One sentence the listener should remember. Empty when the model gave none.
  final String takeaway;

  /// Key points per section, parallel to [headings]. May be shorter than [headings].
  final List<List<String>> points;
}

/// Writes a talk one section at a time so the first part can be spoken and played
/// while later parts are still being written.
abstract interface class ScriptWriter {
  Future<ScriptOutline> outline(ScriptRequest request);

  /// Writes the spoken text for section [index] of [outline], about [words] words long.
  /// [previousText] is the text of the section before it ('' for the first).
  Future<String> writeSection({
    required ScriptRequest request,
    required ScriptOutline outline,
    required int index,
    required int words,
    required String previousText,
  });
}

enum GenerationPhase { models, script, voice }

class GenerationProgress {
  const GenerationProgress(this.phase, this.done, this.total);
  final GenerationPhase phase;
  final int done;
  final int total;
}

/// One step of a capsule being made. A stream of these drives the UI.
///
/// While preparing (models, outline) only [progress] is set. After each spoken piece
/// [capsule] holds everything so far (it grows; [Capsule.complete] is false). The last
/// update has [complete] true. [notice] explains a partial result, for example when
/// something failed after playable parts already existed.
class CapsuleUpdate {
  const CapsuleUpdate({
    this.capsule,
    this.progress,
    this.complete = false,
    this.notice,
  });

  final Capsule? capsule;
  final GenerationProgress? progress;
  final bool complete;
  final String? notice;
}

/// Makes a capsule entirely on this phone, part by part. Errors before the first
/// playable part are thrown on the stream as [GenerationException]; after that, a
/// failure ends the stream with a complete update carrying a [CapsuleUpdate.notice].
/// Cancelling the subscription stops the work and frees native resources.
typedef GenerateCapsule =
    Stream<CapsuleUpdate> Function(CreateCapsuleRequest request);
