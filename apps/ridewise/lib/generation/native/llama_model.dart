import 'package:llamadart/llamadart.dart';

import '../types.dart';

/// Gemma 3 1B (GGUF) running locally through llama.cpp. Loads on first use.
class LlamaTextModel implements TextModel {
  LlamaTextModel(this.modelPath);

  final String modelPath;

  LlamaEngine? _engine;
  Future<LlamaEngine>? _loading;

  Future<LlamaEngine> _load() async {
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModel(
      modelPath,
      // CPU only: the emulator's Vulkan driver is not reliable, and a 1B model is fine on CPU.
      modelParams: const ModelParams(
        contextSize: 4096,
        gpuLayers: 0,
        preferredBackend: GpuBackend.cpu,
      ),
    );
    return _engine = engine;
  }

  @override
  Future<String> complete(String prompt, {required int maxTokens}) async {
    final engine = await (_loading ??= _load());
    final out = StringBuffer();
    await for (final chunk in engine.create([
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt),
    ], params: GenerationParams(maxTokens: maxTokens, temp: 0.7))) {
      final text = chunk.choices.first.delta.content;
      if (text != null) out.write(text);
    }
    return out.toString();
  }

  /// Frees the model's memory so the speech engine has room to run.
  Future<void> release() async {
    final engine = _engine;
    _engine = null;
    _loading = null;
    await engine?.dispose();
  }
}
