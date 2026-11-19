import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/native/llama_model.dart';
import 'package:ridewise/generation/script_writer.dart';
import 'package:ridewise/generation/types.dart';

class Spy implements TextModel {
  Spy(this.inner);
  final TextModel inner;
  @override
  Future<String> complete(String prompt, {required int maxTokens, String? system}) async {
    final out = await inner.complete(prompt, maxTokens: maxTokens, system: system);
    print('--- RAW REPLY ---\n$out\n-----------------');
    try {
      parseOutline(out, 5);
    } catch (e, st) {
      print('PARSE ERROR: $e\n$st');
    }
    return out;
  }
}

Future<void> main() async {
  final model = LlamaTextModel('tool/models/gemma-3-1b-it-Q4_K_M.gguf');
  try {
    final o = await createScriptWriter(Spy(model)).outline(
      const ScriptRequest(
        topic: 'Personal finance',
        style: ListeningStyle.quickOverview,
        language: CapsuleLanguage.enIN,
        targetWords: 1350,
      ),
    );
    print('OK ${o.title} | ${o.headings}');
  } catch (e, st) {
    print('OUTLINE ERROR: $e\n$st');
  }
  await model.release();
}
