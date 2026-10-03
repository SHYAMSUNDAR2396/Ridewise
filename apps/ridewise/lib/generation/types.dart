import '../domain/models.dart';

/// A local language model. Implemented over llamadart on device and by fakes in tests.
abstract interface class TextModel {
  Future<String> complete(String prompt, {required int maxTokens});
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
  final int targetWords;
}

class Script {
  const Script({required this.title, required this.transcript});
  final String title;
  final String transcript;
}

abstract interface class ScriptWriter {
  Future<Script> write(ScriptRequest request);
}

enum GenerationPhase { models, script, voice }

class GenerationProgress {
  const GenerationProgress(this.phase, this.done, this.total);
  final GenerationPhase phase;
  final int done;
  final int total;
}

typedef ProgressCallback = void Function(GenerationProgress progress);

/// Makes a capsule entirely on this phone. The Flutter UI depends on this
/// signature; `native/runtime.dart` provides the real implementation.
typedef GenerateCapsule = Future<Capsule> Function(
  CreateCapsuleRequest request,
  ProgressCallback onProgress,
);
