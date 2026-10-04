import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../domain/models.dart';
import '../pipeline.dart';
import '../script_writer.dart';
import '../types.dart';
import 'llama_model.dart';
import 'model_files.dart';
import 'sherpa_speech.dart';

/// Makes a capsule entirely on this phone, part by part: Gemma writes each section and
/// Kokoro speaks it, so the first part is ready long before the last one is written.
///
/// Both models stay loaded for the whole run (the next section is being written while the
/// current one is spoken) and are freed when the stream ends or its subscriber cancels.
Stream<CapsuleUpdate> generateCapsuleOnDevice(
  CreateCapsuleRequest request,
) async* {
  final percents = StreamController<int>();
  final modelsReady = ensureModels(percents.add).whenComplete(percents.close);
  // An early download failure must not be reported as unhandled before it is awaited below.
  unawaited(modelsReady.then<void>((_) {}, onError: (Object _) {}));

  var lastPercent = -1;
  await for (final percent in percents.stream) {
    if (percent == lastPercent) continue;
    lastPercent = percent;
    yield CapsuleUpdate(
      progress: GenerationProgress(GenerationPhase.models, percent, 100),
    );
  }
  final models = await modelsReady;

  final docs = await documentsPath();
  String capsuleDir(String id) => '$docs/capsules/$id';
  final speech = SherpaSpeech(models.kokoroDir);
  final model = LlamaTextModel(models.gemmaPath);

  try {
    yield* createCapsuleOnDevice(
      request,
      PipelineDeps(
        script: createScriptWriter(model),
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
        deleteFile: (path) async {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        },
      ),
    );
  } finally {
    await model.release();
    await speech.destroy();
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
