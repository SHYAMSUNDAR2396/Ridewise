// ignore_for_file: avoid_relative_lib_imports
import '../../lib/domain/models.dart';
import '../../lib/generation/types.dart';

// A 1B-class local model loses the thread and the format on long outputs, so a
// script is written as a short outline and then one section at a time.
const _tokensPerWord = 1.6;
const _maxOutlineTokens = 200;

int _wordsPerSection(CapsuleLanguage language) =>
    language == CapsuleLanguage.hiIN ? 250 : 300;

String _styleHint(ListeningStyle style) => switch (style) {
  ListeningStyle.quickOverview => 'a concise overview that gets to the point',
  ListeningStyle.learnDeeply =>
    'a deeper explanation with context and examples',
};

String _languageRule(CapsuleLanguage language) => switch (language) {
  CapsuleLanguage.enIN => 'Write in clear Indian English.',
  CapsuleLanguage.hiIN =>
    'Write in natural, simple spoken Hindi in Devanagari script. Common English terms may stay in Latin script.',
};

GenerationException _failed(String message) =>
    GenerationException(CapsuleErrorCode.scriptGenerationFailed, message);

String _stripMarkup(String line) => line
    .replaceFirst(RegExp(r'^[\s>*#\-•\d.)]+'), '')
    .replaceAll(RegExp(r'[*_`#]'), '')
    .trim();

/// First line is the title; the next [sectionCount] lines are section headings.
({String title, List<String> headings}) parseOutline(
  String raw,
  int sectionCount,
) {
  final lines = raw
      .split('\n')
      .map(
        (line) => _stripMarkup(
          line.replaceFirst(RegExp(r'^title\s*:', caseSensitive: false), ''),
        ),
      )
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.isEmpty) throw _failed('The model returned no outline.');
  final title = lines.first;
  final headings = lines.skip(1).take(sectionCount).toList();
  return (title: title, headings: headings.isEmpty ? [title] : headings);
}

final _labelLine = RegExp(
  r'^(section|part|title|heading)\b[^.!?]*:$',
  caseSensitive: false,
);

// A 1B model often wraps its answer in chat filler ("Okay, here's the part:" ... "Let me know if...").
// Spoken aloud it ruins the capsule, so the first and last lines are checked for it.
final _chatPreamble = RegExp(
  r"^(okay|ok|sure|certainly|alright|absolutely|of course|here|great|ज़रूर|जरूर|ठीक है|बिल्कुल|यहाँ|यह रहा).*[:：]$",
  caseSensitive: false,
);
final _chatClosing = RegExp(
  r"^(let me know|would you like|i hope|hope this|feel free|मुझे बताएं|मुझे बताइए|क्या आप)",
  caseSensitive: false,
);

/// Removes markdown, bracketed stage directions, chat filler and leftover labels so the voice never reads them aloud.
String cleanSection(String raw) {
  final lines = raw
      .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ')
      .split('\n')
      .map(
        (line) => line
            .replaceFirst(RegExp(r'^[\s>*#\-•]+'), '')
            .replaceAll(RegExp(r'[*_`]'), '')
            .trim(),
      )
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.isNotEmpty && _chatPreamble.hasMatch(lines.first)) {
    lines.removeAt(0);
  }
  if (lines.isNotEmpty && _chatClosing.hasMatch(lines.last)) {
    lines.removeLast();
  }

  return lines
      .where((line) => !_labelLine.hasMatch(line))
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // A model often wraps the whole talk in quotation marks.
      .replaceAll(RegExp('^[“”"]+|[“”"]+\$'), '')
      .trim();
}

String _lastSentence(String text) {
  final sentences = text
      .split(RegExp(r'(?<=[.!?।])\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  return sentences.isEmpty ? '' : sentences.last;
}

String _outlinePrompt(ScriptRequest request, int sectionCount) => [
  'Plan a spoken audio talk about: ${request.topic}.',
  'It should be ${_styleHint(request.style)}.',
  _languageRule(request.language),
  "Reply with the talk's title on the first line, then exactly $sectionCount lines, each a short heading for one part of the talk, in order.",
  'No numbering, no extra text.',
].join('\n');

String _sectionPrompt({
  required ScriptRequest request,
  required String title,
  required String heading,
  required int index,
  required int total,
  required int words,
  required String previous,
}) {
  final position = total == 1
      ? 'This is the whole talk: give a short opening, the main idea, and a natural closing.'
      : index == 0
      ? 'This is the opening: welcome the listener briefly, then begin.'
      : index == total - 1
      ? 'This is the final part: finish the idea and close the talk naturally.'
      : 'This is a middle part: continue naturally without a greeting or a goodbye.';

  return [
    'You are writing one part of a spoken audio talk titled "$title" about ${request.topic}.',
    'Style: ${_styleHint(request.style)}. ${_languageRule(request.language)}',
    'Write about $words words for the part called "$heading". $position',
    if (previous.isNotEmpty) 'The previous part ended with: "$previous"',
    'Write plain spoken sentences only. No headings, no lists, no markdown, no stage directions, no sound effects.',
    'Be factual and do not present uncertain claims as fact.',
  ].join('\n');
}

/// Sections planned for a talk of [targetWords] words (at least one).
int sectionCountFor(int targetWords, CapsuleLanguage language) =>
    (targetWords / _wordsPerSection(language)).round().clamp(1, 1 << 30);

ScriptWriter createScriptWriterV1(TextModel model) =>
    _SectionedScriptWriter(model);

class _SectionedScriptWriter implements ScriptWriter {
  _SectionedScriptWriter(this._model);
  final TextModel _model;

  @override
  Future<ScriptOutline> outline(ScriptRequest request) async {
    final sectionCount = sectionCountFor(request.targetWords, request.language);
    try {
      final outline = parseOutline(
        await _model.complete(
          _outlinePrompt(request, sectionCount),
          maxTokens: _maxOutlineTokens,
        ),
        sectionCount,
      );
      return ScriptOutline(title: outline.title, headings: outline.headings);
    } on GenerationException {
      rethrow;
    } catch (_) {
      throw _failed('The model could not plan the script.');
    }
  }

  @override
  Future<String> writeSection({
    required ScriptRequest request,
    required ScriptOutline outline,
    required int index,
    required int words,
    required String previousText,
  }) async {
    final String text;
    try {
      text = cleanSection(
        await _model.complete(
          _sectionPrompt(
            request: request,
            title: outline.title,
            heading: outline.headings[index],
            index: index,
            total: outline.headings.length,
            words: words,
            previous: _lastSentence(previousText),
          ),
          maxTokens: (words * _tokensPerWord).ceil() + 60,
        ),
      );
    } catch (_) {
      throw _failed('The model could not write a section.');
    }
    if (text.isEmpty) throw _failed('The model returned an empty section.');
    return text;
  }
}
