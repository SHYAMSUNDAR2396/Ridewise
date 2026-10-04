import '../domain/models.dart';
import 'types.dart';

// A 1B-class local model loses the thread and the format on long outputs, so a
// script is written as a show plan and then one section at a time.
const _tokensPerWord = 1.6;
const _maxOutlineTokens = 360;

// A section that comes back under this share of its word target gets one continuation call.
const _continueBelow = 0.6;
const _minWordsToContinue = 30;

// Near-duplicate sentences share at least this much of their (shorter) word set.
const _repeatOverlap = 0.8;
const _minWordsToJudgeRepeat = 4;

/// The fixed voice of the show, sent as the system message for every section.
const hostPersona =
    'You are the host of Ridewise, a short audio show for commuters in India. '
    'You talk like a smart, friendly person explaining something on a ride: short sentences, '
    'plain words, "you" and "we", contractions, one idea per sentence. '
    'You only write what is spoken aloud. Never write headings, lists, notes or comments about your answer.';

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

String _stripMarkdown(String line) => line
    .replaceAll(RegExp(r'[*_`#]'), '')
    .replaceFirst(RegExp(r'^[\s>]+'), '')
    .trim();

// A line that opens with chat filler ("Okay, here's a plan...", "Sure, here is...").
final _outlinePreamble = RegExp(
  r"^((okay|ok|sure|certainly|alright|absolutely|of course|great)[,!:]|here(['’]s| is| are)\b|(ज़रूर|जरूर|बिल्कुल|यहाँ)[,।:]?)",
  caseSensitive: false,
);

final _titleLabel = RegExp(r'^title\s*[:：]\s*(.*)$', caseSensitive: false);
final _hookLabel = RegExp(r'^hook\s*[:：]\s*(.*)$', caseSensitive: false);
final _takeawayLabel = RegExp(
  r'^take-?away\s*[:：]\s*(.*)$',
  caseSensitive: false,
);
final _numberedLine = RegExp(r'^(?:\d+\s*[.)]|[-•])\s*(.+)$');

String _cleanTitle(String raw) => raw
    .replaceFirst(RegExp(r'^title\s*[:：]\s*', caseSensitive: false), '')
    .replaceAll(RegExp('^[“”"\']+|[“”"\']+\$'), '')
    .trim();

/// Reads the model's show plan. The labelled format is
/// `TITLE:` / `HOOK:` / numbered `heading | point; point` lines / `TAKEAWAY:`; a reply
/// without labels falls back to "first line is the title, then one heading per line".
({
  String title,
  List<String> headings,
  String hook,
  String takeaway,
  List<List<String>> points,
})
parseOutline(String raw, int sectionCount) {
  final lines = raw
      .split('\n')
      .map(_stripMarkdown)
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) throw _failed('The model returned no outline.');

  // Drop chat filler before the plan, but keep a plain reply with only a title and headings.
  while (lines.length > 1 &&
      _outlinePreamble.hasMatch(lines.first) &&
      !_titleLabel.hasMatch(lines.first) &&
      !_hookLabel.hasMatch(lines.first)) {
    lines.removeAt(0);
  }

  final labelled = lines.any(
    (l) =>
        _titleLabel.hasMatch(l) ||
        _hookLabel.hasMatch(l) ||
        _takeawayLabel.hasMatch(l) ||
        RegExp(r'^\d+\s*[.)]\s*.+\|').hasMatch(l),
  );

  if (!labelled) {
    final plain = lines
        .map((l) => _stripMarkup(l.replaceFirst(_titleLabel, r'')))
        .where((l) => l.isNotEmpty)
        .toList();
    final title = _cleanTitle(plain.first);
    final headings = plain.skip(1).take(sectionCount).toList();
    return (
      title: title,
      headings: headings.isEmpty ? [title] : headings,
      hook: '',
      takeaway: '',
      points: const <List<String>>[],
    );
  }

  var title = '';
  var hook = '';
  var takeaway = '';
  final headings = <String>[];
  final points = <List<String>>[];
  for (final line in lines) {
    final t = _titleLabel.firstMatch(line);
    final h = _hookLabel.firstMatch(line);
    final k = _takeawayLabel.firstMatch(line);
    if (t != null) {
      title = _cleanTitle(t.group(1)!);
    } else if (h != null) {
      hook = h.group(1)!.trim();
    } else if (k != null) {
      takeaway = k.group(1)!.trim();
    } else {
      final n = _numberedLine.firstMatch(line);
      if (n != null && headings.length < sectionCount) {
        final parts = n.group(1)!.split('|');
        final heading = parts.first.trim();
        if (heading.isEmpty) continue;
        headings.add(heading);
        points.add(
          parts.length > 1
              ? parts
                    .skip(1)
                    .join('|')
                    .split(';')
                    .map((p) => p.trim())
                    .where((p) => p.isNotEmpty)
                    .toList()
              : <String>[],
        );
      } else if (title.isEmpty && n == null) {
        title = _cleanTitle(line);
      }
    }
  }
  if (headings.isEmpty) {
    headings.add(title.isEmpty ? 'The main ideas' : title);
    points.add(<String>[]);
  }
  return (
    title: title,
    headings: headings,
    hook: hook,
    takeaway: takeaway,
    points: points,
  );
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

final _sentenceBoundary = RegExp(r'(?<=[.!?।])\s+');

List<String> _sentences(String text) =>
    text.split(_sentenceBoundary).where((s) => s.trim().isNotEmpty).toList();

String _lastSentences(String text, int count) {
  final all = _sentences(text);
  return all.skip(all.length > count ? all.length - count : 0).join(' ');
}

int _wordCount(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

Set<String> _wordSet(String sentence) => RegExp(
  r'[\p{L}\p{M}\p{N}]+',
  unicode: true,
).allMatches(sentence.toLowerCase()).map((m) => m.group(0)!).toSet();

bool _nearDuplicate(Set<String> a, Set<String> b) {
  if (a.length < _minWordsToJudgeRepeat || b.length < _minWordsToJudgeRepeat) {
    return false;
  }
  final shared = a.intersection(b).length;
  final smaller = a.length < b.length ? a.length : b.length;
  return shared / smaller >= _repeatOverlap;
}

/// Removes sentences that say again what [earlier] (or the text itself) already said.
/// Short sentences are never judged. If everything would be dropped the text is kept as is.
String dropRepeats(String text, String earlier) {
  final seen = [for (final s in _sentences(earlier)) _wordSet(s)];
  final kept = <String>[];
  for (final sentence in _sentences(text)) {
    final words = _wordSet(sentence);
    if (seen.any((prior) => _nearDuplicate(words, prior))) continue;
    seen.add(words);
    kept.add(sentence.trim());
  }
  return kept.isEmpty ? text : kept.join(' ');
}

final _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
  unicode: true,
);

/// Turns symbols and abbreviations the voice mispronounces into words, and removes links and emoji.
String speakable(String text, CapsuleLanguage language) {
  var out = text
      .replaceAll(RegExp(r'(https?://|www\.)\S+'), ' ')
      .replaceAll(_emoji, ' ')
      .replaceAllMapped(
        RegExp(r'₹\s?(\d[\d,]*(?:\.\d+)?)'),
        (m) => '${m[1]} rupees',
      )
      .replaceAllMapped(
        RegExp(r'\bRs\.?\s?(\d[\d,]*(?:\.\d+)?)'),
        (m) => '${m[1]} rupees',
      )
      .replaceAll('₹', ' rupees ')
      .replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)\s?%'),
        (m) => '${m[1]} percent',
      )
      .replaceAll('%', ' percent ')
      .replaceAll('&', ' and ');
  if (language == CapsuleLanguage.enIN) {
    out = out
        .replaceAll(RegExp(r'\be\.g\.', caseSensitive: false), 'for example')
        .replaceAll(RegExp(r'\bi\.e\.', caseSensitive: false), 'that is')
        .replaceAll(RegExp(r'\betc\.', caseSensitive: false), 'and so on.')
        .replaceAll(RegExp(r'\bvs\.', caseSensitive: false), 'versus');
  }
  return out
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'\s+([,.!?।])'), r'$1')
      .trim();
}

String _showName(CapsuleLanguage language) =>
    language == CapsuleLanguage.hiIN ? 'राइडवाइज़' : 'ridewise';

String _openingLine(CapsuleLanguage language) =>
    language == CapsuleLanguage.hiIN ? 'यह है राइडवाइज़।' : 'This is Ridewise.';

String _signOff(CapsuleLanguage language) => language == CapsuleLanguage.hiIN
    ? 'यह था आपका राइडवाइज़ इस सफ़र के लिए।'
    : "That's your Ridewise for this ride.";

/// A 1B model rarely follows "name the show" reliably, so the show name in the opening and the
/// sign-off at the end are added here when missing.
String ensureBranding(
  String text, {
  required bool isOpening,
  required bool isFinal,
  CapsuleLanguage language = CapsuleLanguage.enIN,
}) {
  var out = text.trim();
  final lower = out.toLowerCase().replaceAll('’', "'");
  if (isOpening && !lower.contains(_showName(language))) {
    final parts = _sentences(out);
    out = parts.length >= 2
        ? [parts.first, _openingLine(language), ...parts.skip(1)].join(' ')
        : '$out ${_openingLine(language)}';
  }
  final signOff = _signOff(language);
  if (isFinal &&
      !out
          .toLowerCase()
          .replaceAll('’', "'")
          .contains(signOff.toLowerCase().substring(0, signOff.length - 1))) {
    out = '$out $signOff';
  }
  return out;
}

String _outlinePrompt(ScriptRequest request, int sectionCount) => [
  'Plan a short spoken audio talk about: ${request.topic}.',
  'It should be ${_styleHint(request.style)}.',
  _languageRule(request.language),
  'Reply in exactly this format and nothing else:',
  'TITLE: a catchy title of at most 8 words',
  'HOOK: one surprising fact or question to open the talk',
  'then exactly $sectionCount lines numbered 1 to $sectionCount, each written as: a short heading | one or two key points separated by semicolons',
  'TAKEAWAY: one sentence the listener should remember',
  'If the topic is unsafe, hateful, sexual, or asks for personal medical, legal or financial advice, plan a short, polite talk that explains why you cannot cover it and covers a safe related topic instead.',
].join('\n');

String _sectionPrompt({
  required ScriptRequest request,
  required ScriptOutline outline,
  required int index,
  required int words,
  required String previousText,
}) {
  final total = outline.headings.length;
  final heading = outline.headings[index];
  final points = index < outline.points.length
      ? outline.points[index]
      : const <String>[];
  final covered = outline.headings.take(index).toList();
  final upcoming = outline.headings.skip(index + 1).toList();
  final lastTwo = _lastSentences(previousText, 2);
  final isOpening = index == 0;
  final isFinal = index == total - 1;
  final hook = outline.hook.isEmpty
      ? 'one surprising fact or question about ${request.topic}'
      : '"${outline.hook}"';
  final takeaway = outline.takeaway.isEmpty
      ? 'the main idea of the talk'
      : '"${outline.takeaway}"';

  final role = isOpening && isFinal
      ? 'This is the whole talk. Start with this hook: $hook. Then explain the key points, and finish with a two-sentence recap built on this takeaway: $takeaway. Do not say goodbye; a sign-off is added for you.'
      : isOpening
      ? 'This is the opening of the talk. Start with this hook: $hook. Do not greet with "Namaste everyone". Then, in one sentence, say what you will cover: ${upcoming.join(', ')}. Then cover the points for this part.'
      : isFinal
      ? 'This is the final part. Begin with one short sentence that connects from "${outline.headings[index - 1]}". Cover the points, then finish with a two-sentence recap built on this takeaway: $takeaway. Do not say goodbye; a sign-off is added for you.'
      : 'This is a middle part. Begin with one short sentence that connects from "${outline.headings[index - 1]}" to this part. Do not greet or say goodbye. End with one short sentence that leads into "${outline.headings[index + 1]}".';

  return [
    'You are writing part ${index + 1} of $total of a spoken talk titled "${outline.title}" about ${request.topic}.',
    'Style: ${_styleHint(request.style)}. ${_languageRule(request.language)}',
    'This part is called "$heading". Write about $words words.',
    if (points.isNotEmpty)
      'Cover these points: ${points.join('; ')}. Give one concrete everyday example in an Indian setting for each, using words rather than symbols.',
    role,
    if (covered.isNotEmpty)
      'Already covered, so do not repeat it: ${covered.join('; ')}.',
    if (lastTwo.isNotEmpty) 'The talk so far ended with: "$lastTwo"',
    'Use well-known, general facts. Avoid exact statistics, dates or numbers unless you are sure; say "roughly" when unsure.',
    'Write plain spoken sentences only. No headings, no lists, no markdown, no stage directions, no sound effects. Say "rupees" and "percent" as words.',
  ].join('\n');
}

/// Sections planned for a talk of [targetWords] words (at least one).
int sectionCountFor(int targetWords, CapsuleLanguage language) =>
    (targetWords / _wordsPerSection(language)).round().clamp(1, 1 << 30);

ScriptWriter createScriptWriter(TextModel model) =>
    _SectionedScriptWriter(model);

class _SectionedScriptWriter implements ScriptWriter {
  _SectionedScriptWriter(this._model);
  final TextModel _model;

  @override
  Future<ScriptOutline> outline(ScriptRequest request) async {
    final sectionCount = sectionCountFor(request.targetWords, request.language);
    try {
      final o = parseOutline(
        await _model.complete(
          _outlinePrompt(request, sectionCount),
          maxTokens: _maxOutlineTokens,
          system: hostPersona,
        ),
        sectionCount,
      );
      // A title that is really chat filler, or far too long, is replaced by the topic.
      final badTitle =
          o.title.isEmpty ||
          _outlinePreamble.hasMatch(o.title) ||
          _wordCount(o.title) > 14;
      return ScriptOutline(
        title: badTitle ? request.topic : o.title,
        headings: o.headings,
        hook: o.hook,
        takeaway: o.takeaway,
        points: o.points,
      );
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
    String polish(String raw, String earlier) =>
        dropRepeats(speakable(cleanSection(raw), request.language), earlier);

    var text = '';
    try {
      text = polish(
        await _model.complete(
          _sectionPrompt(
            request: request,
            outline: outline,
            index: index,
            words: words,
            previousText: previousText,
          ),
          maxTokens: (words * _tokensPerWord).ceil() + 60,
          system: hostPersona,
        ),
        previousText,
      );
    } catch (_) {
      throw _failed('The model could not write a section.');
    }
    if (text.isEmpty) throw _failed('The model returned an empty section.');

    // One bounded top-up when the model wrote far less than asked; never more than one call.
    final written = _wordCount(text);
    if (words >= _minWordsToContinue && written < words * _continueBelow) {
      try {
        final more = polish(
          await _model.complete(
            'Continue the same part, "${outline.headings[index]}", for about ${words - written} more words, '
            'starting right after this sentence: "${_lastSentences(text, 1)}". '
            'Do not repeat anything already said. Write plain spoken sentences only.',
            maxTokens: ((words - written) * _tokensPerWord).ceil() + 60,
            system: hostPersona,
          ),
          '$previousText $text',
        );
        if (more.isNotEmpty) text = '$text $more';
      } catch (_) {
        // The first answer is still a usable section.
      }
    }

    return ensureBranding(
      text,
      isOpening: index == 0,
      isFinal: index == outline.headings.length - 1,
      language: request.language,
    );
  }
}
