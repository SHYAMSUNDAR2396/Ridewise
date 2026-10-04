import 'dart:io';
import 'dart:math';

import '../../domain/models.dart';
import '../pipeline.dart';
import '../script_writer.dart';
import '../types.dart';
import 'llama_model.dart';
import 'model_files.dart';
import 'sherpa_speech.dart';

/// Makes a capsule entirely on this phone: Gemma writes the script, Kokoro speaks it.
Future<Capsule> generateCapsuleOnDevice(
  CreateCapsuleRequest request,
  ProgressCallback onProgress,
) async {
  final models = await ensureModels(
    (percent) =>
        onProgress(GenerationProgress(GenerationPhase.models, percent, 100)),
  );
  final docs = await documentsPath();
  final speech = SherpaSpeech(models.kokoroDir);
  String capsuleDir(String id) => '$docs/capsules/$id';

  try {
    return await createCapsuleOnDevice(
      request,
      PipelineDeps(
        script: _GemmaScriptWriter(models.gemmaPath),
        speech: _DirectoryCreatingSpeech(speech),
        segmentPath: (id, index) => '${capsuleDir(id)}/segment-$index.wav',
        newId: () =>
            '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-'
            '${Random().nextInt(1 << 32).toRadixString(36)}',
        now: DateTime.now,
        cleanup: (id) async {
          final dir = Directory(capsuleDir(id));
          if (dir.existsSync()) await dir.delete(recursive: true);
        },
        onProgress: onProgress,
      ),
    );
  } finally {
    await speech.destroy();
  }
}

/// Loads Gemma for one script, then frees its memory before the voice model starts working.
class _GemmaScriptWriter implements ScriptWriter {
  _GemmaScriptWriter(this.modelPath);
  final String modelPath;

  @override
  Future<Script> write(ScriptRequest request) async {
    final model = LlamaTextModel(modelPath);
    try {
      return await createScriptWriter(model).write(request);
    } finally {
      await model.release();
    }
  }
}

class _DirectoryCreatingSpeech implements SpeechEngine {
  _DirectoryCreatingSpeech(this._inner);
  final SherpaSpeech _inner;

  @override
  Future<({double durationSeconds})> synthesizeToFile(
    String text,
    String filePath,
    CapsuleLanguage language,
  ) async {
    await Directory(
      filePath.substring(0, filePath.lastIndexOf('/')),
    ).create(recursive: true);
    return _inner.synthesizeToFile(text, filePath, language);
  }
}
