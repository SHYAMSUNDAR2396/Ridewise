import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

const kokoroId = 'kokoro-int8-multi-lang-v1_0';
const _kokoroUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$kokoroId.tar.bz2';
const _kokoroMarker = '.complete';

const gemmaFile = 'gemma-3-1b-it-Q4_K_M.gguf';
const _gemmaUrl =
    'https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/$gemmaFile';
const _gemmaBytes = 806058272;

// Share of the overall 0-100 progress spent on the small speech model.
const _kokoroShare = 15;

class ModelPaths {
  const ModelPaths({required this.kokoroDir, required this.gemmaPath});
  final String kokoroDir;
  final String gemmaPath;
}

Future<String> documentsPath() async =>
    (await getApplicationDocumentsDirectory()).path;

/// Downloads and unpacks the speech and script models on first use. Reports 0 to 100 across both.
Future<ModelPaths> ensureModels(void Function(int percent) onPercent) async {
  final modelsDir = '${await documentsPath()}/models';
  await Directory(modelsDir).create(recursive: true);
  final dio = Dio();

  final kokoroDir = '$modelsDir/$kokoroId';
  if (!File('$kokoroDir/$_kokoroMarker').existsSync()) {
    await _downloadKokoro(dio, modelsDir, kokoroDir, onPercent);
  }
  onPercent(_kokoroShare);

  final gemmaPath = '$modelsDir/$gemmaFile';
  if (!File(gemmaPath).existsSync() ||
      File(gemmaPath).lengthSync() != _gemmaBytes) {
    await _downloadFile(
      dio,
      _gemmaUrl,
      gemmaPath,
      _gemmaBytes,
      (ratio) =>
          onPercent(_kokoroShare + (ratio * (100 - _kokoroShare)).round()),
    );
  }
  onPercent(100);
  dio.close();
  return ModelPaths(kokoroDir: kokoroDir, gemmaPath: gemmaPath);
}

Future<void> _downloadKokoro(
  Dio dio,
  String modelsDir,
  String kokoroDir,
  void Function(int percent) onPercent,
) async {
  final archive = '$modelsDir/$kokoroId.tar.bz2';
  // 0-10% is the download, 10-15% is unpacking (which has no progress of its own).
  // Only a finished download is ever renamed to its final name, so an existing archive is complete.
  if (!File(archive).existsSync()) {
    await _downloadFile(
      dio,
      _kokoroUrl,
      archive,
      null,
      (ratio) => onPercent((ratio * 10).round()),
    );
  }
  onPercent(10);
  if (Directory(kokoroDir).existsSync()) {
    await Directory(kokoroDir).delete(recursive: true);
  }
  // Heavy decode runs off the UI isolate; the bz2 is streamed to a temp tar, not held in memory.
  await _extractOffThread(archive, modelsDir);
  await File('$kokoroDir/$_kokoroMarker').writeAsString('ok');
  await File(archive).delete();
}

// Not async and with only plain arguments in scope, so the closure sent to the isolate captures nothing else.
Future<void> _extractOffThread(String archive, String outDir) =>
    Isolate.run(() => extractFileToDisk(archive, outDir));

/// Downloads to `<dest>.part` and renames only once complete (and the size matches, when known).
Future<void> _downloadFile(
  Dio dio,
  String url,
  String dest,
  int? expectedBytes,
  void Function(double ratio) onRatio,
) async {
  // Unique per run, so two overlapping runs (e.g. an activity restart) never clobber each other.
  final part = '$dest.${DateTime.now().microsecondsSinceEpoch}.part';
  await dio.download(
    url,
    part,
    onReceiveProgress: (received, total) {
      final denominator = total > 0 ? total : (expectedBytes ?? 0);
      if (denominator > 0) onRatio(received / denominator);
    },
  );
  if (expectedBytes != null && File(part).lengthSync() != expectedBytes) {
    await File(part).delete();
    throw StateError('Download of ${dest.split('/').last} was incomplete.');
  }
  if (File(dest).existsSync() &&
      (expectedBytes == null || File(dest).lengthSync() == expectedBytes)) {
    await File(part).delete(); // another run finished first
    return;
  }
  await File(part).rename(dest);
}
