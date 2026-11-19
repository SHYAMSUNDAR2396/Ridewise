import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/script_writer.dart';
import 'package:ridewise/generation/types.dart';

class FakeModel implements TextModel {
  FakeModel(this.replies);
  final List<String> replies;
  final prompts = <String>[];
  final maxTokens = <int>[];
  final systems = <String?>[];

  @override
  Future<String> complete(
    String prompt, {
    required int maxTokens,
    String? system,
  }) async {
    prompts.add(prompt);
    this.maxTokens.add(maxTokens);
    systems.add(system);
    if (replies.isEmpty) throw Exception('no more replies');
    return replies.removeAt(0);
  }
}

ScriptRequest request({
  int words = 300,
  CapsuleLanguage language = CapsuleLanguage.enIN,
}) => ScriptRequest(
  topic: 'Personal finance',
  style: ListeningStyle.quickOverview,
  language: language,
  targetWords: words,
);

Matcher failsWith(CapsuleErrorCode code) =>
    throwsA(isA<GenerationException>().having((e) => e.code, 'code', code));

void main() {
  group('parseOutline', () {
    test(
      'takes the first line as the title and strips numbering and markdown',
      () {
        final outline = parseOutline(
          'Title: **Index Funds**\n1. What they are\n2) Why fees matter\n- Getting started',
          3,
        );
        expect(outline.title, 'Index Funds');
        expect(outline.headings, [
          'What they are',
          'Why fees matter',
          'Getting started',
        ]);
      },
    );

    test(
      'ignores extra headings and falls back to the title when there are none',
      () {
        expect(parseOutline('T\nA\nB\nC', 2).headings, ['A', 'B']);
        expect(parseOutline('Only a title', 3).headings, ['Only a title']);
      },
    );

    test('rejects an empty reply', () {
      expect(
        () => parseOutline('  \n ', 2),
        failsWith(CapsuleErrorCode.scriptGenerationFailed),
      );
    });
  });

  group('cleanSection', () {
    test('removes markdown, stage directions and label lines', () {
      const raw =
          '**Part 1:**\n[soft music]\n- Welcome to the show (pause) everyone.\n# Heading\nThis is *fine*.';
      expect(
        cleanSection(raw),
        'Welcome to the show everyone. Heading This is fine.',
      );
    });

    test('drops the chat preamble a small model adds before the script', () {
      expect(
        cleanSection(
          "Okay, here's a piece about 'Let's face it, managing your finances' in the style you requested:\n\nMoney is a tool. Use it well.",
        ),
        'Money is a tool. Use it well.',
      );
      expect(
        cleanSection(
          'Sure, here is the opening part of the audio talk:\nWelcome aboard.',
        ),
        'Welcome aboard.',
      );
      expect(
        cleanSection(
          'ज़रूर, यहाँ एक ऑडियो स्क्रिप्ट के लिए 80 शब्दों में सरल हिंदी में दिया गया है:\nनमस्ते दोस्तों।',
        ),
        'नमस्ते दोस्तों।',
      );
    });

    test('removes quotation marks wrapped around the whole section', () {
      expect(
        cleanSection('“Namaste everyone. Welcome back.”'),
        'Namaste everyone. Welcome back.',
      );
      expect(
        cleanSection('He said "save early" and left.'),
        'He said "save early" and left.',
      );
    });

    test(
      'drops a closing offer but keeps ordinary sentences ending in a colon',
      () {
        expect(
          cleanSection(
            'Save a little every month.\nLet me know if you would like a longer version!',
          ),
          'Save a little every month.',
        );
        expect(
          cleanSection('Here is why it matters: small habits compound.'),
          'Here is why it matters: small habits compound.',
        );
      },
    );
  });

  group('parseOutline v2 (show plan)', () {
    test(
      'reads title, hook, numbered headings with key points, and takeaway',
      () {
        const raw = '''TITLE: Money Basics for Beginners
HOOK: Did you know most people can't say where last month's salary went?
1. What money is | income and expenses; why tracking matters
2. Saving early | the habit beats the amount; small steps
TAKEAWAY: Know where your money goes before you decide where it should go.''';
        final o = parseOutline(raw, 5);
        expect(o.title, 'Money Basics for Beginners');
        expect(o.hook, startsWith('Did you know'));
        expect(o.headings, ['What money is', 'Saving early']);
        expect(o.points, [
          ['income and expenses', 'why tracking matters'],
          ['the habit beats the amount', 'small steps'],
        ]);
        expect(o.takeaway, startsWith('Know where your money goes'));
      },
    );

    test('drops a chat preamble line before the plan', () {
      final o = parseOutline(
        "Okay, here's a plan for a talk about personal finance:\nTITLE: Your Money, Simplified\n1. Earning | income\n2. Spending | budgets",
        5,
      );
      expect(o.title, 'Your Money, Simplified');
      expect(o.headings, ['Earning', 'Spending']);
    });

    test('drops a preamble even when it has no colon and is not labelled', () {
      final o = parseOutline(
        "Okay, here's a spoken audio talk about Personal finance\nYour Money, Simplified\nEarning\nSpending",
        5,
      );
      expect(o.title, 'Your Money, Simplified');
      expect(o.headings, ['Earning', 'Spending']);
    });

    test('limits headings to the requested count and keeps points aligned', () {
      final o = parseOutline(
        'TITLE: T\n1. A | a1\n2. B | b1\n3. C | c1\n4. D | d1',
        2,
      );
      expect(o.headings, ['A', 'B']);
      expect(o.points, [
        ['a1'],
        ['b1'],
      ]);
    });

    test('recovers a heading and points from a semicolon list with no bar', () {
      final o = parseOutline(
        'TITLE: T\n1. Start small; begin with basic budgeting; we will build from there\n2. Track spending; use a notebook',
        5,
      );
      expect(o.headings, ['Start small', 'Track spending']);
      expect(o.points, [
        ['begin with basic budgeting', 'we will build from there'],
        ['use a notebook'],
      ]);
    });

    test('falls back to the plain format when there are no labels', () {
      final o = parseOutline('A Title\nFirst part\nSecond part', 5);
      expect(o.title, 'A Title');
      expect(o.headings, ['First part', 'Second part']);
      expect(o.hook, '');
      expect(o.takeaway, '');
      expect(o.points, isEmpty);
    });
  });

  group('dropRepeats', () {
    test('removes sentences that repeat earlier text, keeps new ones', () {
      expect(
        dropRepeats(
          'Managing your money can feel overwhelming. Start by tracking spending for a month.',
          'Let us face it, managing your money can feel overwhelming. Income comes first.',
        ),
        'Start by tracking spending for a month.',
      );
    });

    test('removes near-duplicates inside the same text', () {
      expect(
        dropRepeats(
          'Save a little every month. Save a little each month. Then invest it.',
          '',
        ),
        'Save a little every month. Then invest it.',
      );
    });

    test('never drops short sentences and handles Devanagari', () {
      expect(dropRepeats('Great. Great. Done.', ''), 'Great. Great. Done.');
      expect(
        dropRepeats(
          'हर महीने थोड़ा बचाइए। हर महीने थोड़ा बचाइए। फिर निवेश कीजिए।',
          '',
        ),
        'हर महीने थोड़ा बचाइए। फिर निवेश कीजिए।',
      );
    });

    test('returns the text unchanged when nothing repeats', () {
      expect(
        dropRepeats(
          'One new idea here today. Another fresh thought follows.',
          'Old text about something else entirely.',
        ),
        'One new idea here today. Another fresh thought follows.',
      );
    });
  });

  group('speakable', () {
    test('turns symbols the voice mispronounces into words', () {
      expect(
        speakable(
          'Save ₹5,000 a month, about 20% of your pay & more.',
          CapsuleLanguage.enIN,
        ),
        'Save 5,000 rupees a month, about 20 percent of your pay and more.',
      );
      expect(
        speakable('Use SIPs, e.g. index funds, etc.', CapsuleLanguage.enIN),
        'Use SIPs, for example index funds, and so on.',
      );
    });

    test('strips links and emoji in every language', () {
      expect(
        speakable(
          'See https://example.com/page now 😀 please.',
          CapsuleLanguage.enIN,
        ),
        'See now please.',
      );
      expect(
        speakable('यह 50% सही है 🙂', CapsuleLanguage.hiIN),
        'यह 50 percent सही है',
      );
    });
  });

  group('branding', () {
    test('adds the show name after the first sentence of the opening', () {
      expect(
        ensureBranding(
          'Most people never track money. Let us fix that.',
          isOpening: true,
          isFinal: false,
        ),
        'Most people never track money. This is Ridewise. Let us fix that.',
      );
    });

    test('keeps an opening that already names the show', () {
      const t = 'Welcome to Ridewise. Today we talk money.';
      expect(ensureBranding(t, isOpening: true, isFinal: false), t);
    });

    test('adds the sign-off to the final section once', () {
      expect(
        ensureBranding(
          'Remember to track your spending.',
          isOpening: false,
          isFinal: true,
        ),
        "Remember to track your spending. That's your Ridewise for this ride.",
      );
      const t = "Remember. That's your Ridewise for this ride.";
      expect(ensureBranding(t, isOpening: false, isFinal: true), t);
    });

    test('a single-section talk gets both', () {
      final out = ensureBranding(
        'Hook line here. Main idea follows.',
        isOpening: true,
        isFinal: true,
      );
      expect(out, contains('This is Ridewise.'));
      expect(out, endsWith("That's your Ridewise for this ride."));
    });
  });

  group('section prompts v2', () {
    ScriptOutline plan() => const ScriptOutline(
      title: 'Money Basics',
      headings: ['What money is', 'Saving early', 'Investing'],
      hook: 'Where did last month go?',
      takeaway: 'Track first, then decide.',
      points: [
        ['income', 'expenses'],
        ['habit beats amount'],
        ['start small'],
      ],
    );

    test('opening: hook, preview, system persona', () async {
      final model = FakeModel(['Where did last month go? Good question.']);
      await createScriptWriter(model).writeSection(
        request: request(words: 900),
        outline: plan(),
        index: 0,
        words: 250,
        previousText: '',
      );
      final prompt = model.prompts.first;
      expect(prompt, contains('Where did last month go?'));
      expect(prompt, contains('opening'));
      expect(prompt, contains('Saving early'));
      expect(prompt, contains('income'));
      expect(model.systems.first, contains('Ridewise'));
    });

    test(
      'middle: bridge, already-covered headings, last two sentences',
      () async {
        final model = FakeModel([
          'Next we look at habits and steady steps forward, one small idea after another, told simply so it sticks with you on the ride.',
        ]);
        await createScriptWriter(model).writeSection(
          request: request(words: 900),
          outline: plan(),
          index: 1,
          words: 20,
          previousText: 'First idea here. Second idea here. Third idea here.',
        );
        final prompt = model.prompts.first;
        expect(prompt, contains('Already covered'));
        expect(prompt, contains('What money is'));
        expect(prompt, contains('Second idea here. Third idea here.'));
        expect(prompt, isNot(contains('First idea here.')));
        expect(prompt, contains('habit beats amount'));
        expect(prompt, contains('Investing'));
      },
    );

    test(
      'keeps each part to itself and does not leak formatting rules',
      () async {
        final model = FakeModel([
          'Where did last month go? Good question, and we will find out together on this ride today.',
        ]);
        await createScriptWriter(model).writeSection(
          request: request(words: 900),
          outline: plan(),
          index: 0,
          words: 20,
          previousText: '',
        );
        final prompt = model.prompts.first;
        expect(prompt, contains('Do not cover these later parts'));
        expect(prompt, contains('Saving early'));
        expect(prompt, isNot(contains('as words')));
        expect(model.systems.first, contains('10 to 20 words'));
      },
    );

    test('final: recap on the takeaway and sign-off', () async {
      final model = FakeModel([
        'Start small and keep going every week of the year, because steady habits quietly beat big bursts of effort over time.',
      ]);
      final text = await createScriptWriter(model).writeSection(
        request: request(words: 900),
        outline: plan(),
        index: 2,
        words: 20,
        previousText: 'Earlier text. More earlier text.',
      );
      expect(model.prompts.first, contains('Track first, then decide.'));
      expect(text, endsWith("That's your Ridewise for this ride."));
    });

    test('adds one continuation when a section comes back too short', () async {
      final model = FakeModel([
        'A short answer only.',
        'Here is a lot more useful material that was missing before, told simply and clearly for you to hear today.',
      ]);
      final text = await createScriptWriter(model).writeSection(
        request: request(words: 900),
        outline: plan(),
        index: 1,
        words: 200,
        previousText: 'Earlier.',
      );
      expect(model.prompts, hasLength(2));
      expect(model.prompts[1], contains('Continue'));
      expect(model.prompts[1], contains('A short answer only.'));
      expect(text, contains('A short answer only.'));
      expect(text, contains('missing before'));
    });

    test('does not continue when the section is long enough', () async {
      final long = List.filled(150, 'word').join(' ');
      final model = FakeModel(['$long.']);
      await createScriptWriter(model).writeSection(
        request: request(words: 900),
        outline: plan(),
        index: 1,
        words: 200,
        previousText: 'Earlier.',
      );
      expect(model.prompts, hasLength(1));
    });

    test(
      'drops sentences repeated from earlier text and speaks symbols',
      () async {
        final model = FakeModel([
          'Managing your money can feel overwhelming. Put away ₹500 a week, that is about 5% of income.',
        ]);
        final text = await createScriptWriter(model).writeSection(
          request: request(words: 900),
          outline: plan(),
          index: 1,
          words: 10,
          previousText: 'Managing your money can feel overwhelming.',
        );
        expect(text, isNot(contains('overwhelming')));
        expect(text, contains('500 rupees'));
        expect(text, contains('5 percent'));
      },
    );
  });

  group('outline v2', () {
    test('replaces sentence-like headings with neutral ones', () async {
      final model = FakeModel([
        'TITLE: Money Matters\nHOOK: Ever wonder where it goes?\n1. Okay, let us be honest, do you ever think about how much you earn?\n2. It is easy to just spend without thinking, is it not?\n3. Think about what you are saving for - a new phone?',
      ]);
      final o = await createScriptWriter(model).outline(request(words: 900));
      expect(o.headings, hasLength(3));
      expect(o.headings.every((h) => h.split(' ').length <= 4), isTrue);
      expect(o.headings.any((h) => h.contains('?')), isFalse);
      expect(o.points, isEmpty);
      expect(o.title, 'Money Matters');
    });

    test('keeps good short headings', () async {
      final model = FakeModel([
        'TITLE: T\nHOOK: H\n1. Know your income\n2. Track spending\n3. Build a safety net',
      ]);
      final o = await createScriptWriter(model).outline(request(words: 900));
      expect(o.headings, [
        'Know your income',
        'Track spending',
        'Build a safety net',
      ]);
    });

    test('shows a worked example so a small model copies the format', () async {
      final model = FakeModel(['TITLE: T\n1. A\n2. B\n3. C']);
      await createScriptWriter(model).outline(request(words: 900));
      expect(model.prompts.single, contains('Example'));
    });

    test(
      'asks for the show plan format and includes the unsafe-topic rule',
      () async {
        final model = FakeModel(['TITLE: T\nHOOK: H\n1. A | a\nTAKEAWAY: X']);
        final o = await createScriptWriter(model).outline(request(words: 300));
        final prompt = model.prompts.single;
        expect(prompt, contains('TITLE:'));
        expect(prompt, contains('HOOK:'));
        expect(prompt, contains('TAKEAWAY:'));
        expect(prompt, contains('unsafe'));
        expect(prompt, contains('2 to 5 words'));
        expect(prompt, contains('no statistics'));
        expect(o.hook, 'H');
      },
    );

    test(
      'uses a topic-based title when the model gives filler as a title',
      () async {
        final model = FakeModel(["Okay, here's a plan for you:\n1. First | a"]);
        final o = await createScriptWriter(model).outline(request(words: 300));
        expect(o.title, 'Personal finance');
      },
    );
  });

  group('sectionCountFor', () {
    test(
      'is at least one and uses 300 words per English section, 250 per Hindi',
      () {
        expect(sectionCountFor(10, CapsuleLanguage.enIN), 1);
        expect(sectionCountFor(600, CapsuleLanguage.enIN), 2);
        expect(sectionCountFor(2700, CapsuleLanguage.enIN), 9);
        expect(sectionCountFor(500, CapsuleLanguage.hiIN), 2);
        expect(sectionCountFor(2340, CapsuleLanguage.hiIN), 9);
      },
    );
  });

  group('outline', () {
    test(
      'asks for the planned number of headings and returns the title and headings',
      () async {
        final model = FakeModel(['Money Basics\nWhat money is\nSaving early']);
        final outline = await createScriptWriter(
          model,
        ).outline(request(words: 600));

        expect(outline.title, 'Money Basics');
        expect(outline.headings, ['What money is', 'Saving early']);
        expect(model.prompts, hasLength(1));
        expect(model.prompts.single, contains('exactly 2 lines'));
        expect(model.prompts.single, contains('clear Indian English'));
      },
    );

    test(
      'asks for Devanagari Hindi and plans shorter sections for hi-IN',
      () async {
        final model = FakeModel(['शीर्षक\nपहला\nदूसरा']);
        await createScriptWriter(
          model,
        ).outline(request(words: 500, language: CapsuleLanguage.hiIN));

        expect(model.prompts.single, contains('exactly 2 lines')); // 500 / 250
        expect(model.prompts.single, contains('Devanagari'));
        expect(model.prompts.single, isNot(contains('Indian English')));
      },
    );

    test(
      'fails with scriptGenerationFailed when the model errors or returns nothing',
      () async {
        await expectLater(
          createScriptWriter(FakeModel([])).outline(request()),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
        await expectLater(
          createScriptWriter(FakeModel(['  '])).outline(request()),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
      },
    );
  });

  group('writeSection', () {
    const outline = ScriptOutline(
      title: 'Money Basics',
      headings: ['What money is', 'Saving', 'Starting out'],
    );

    Future<String> write(
      FakeModel model, {
      int index = 0,
      int words = 100,
      String previous = '',
      CapsuleLanguage language = CapsuleLanguage.enIN,
    }) => createScriptWriter(model).writeSection(
      request: request(language: language),
      outline: outline,
      index: index,
      words: words,
      previousText: previous,
    );

    test(
      'writes the opening, a middle part and the closing with matching instructions',
      () async {
        final model = FakeModel([
          'Money is a tool.',
          'Save early.',
          'Start today.',
        ]);

        // Small word budgets so no top-up call is made; the show name and sign-off are added.
        expect(
          await write(model, index: 0, words: 20),
          'Money is a tool. This is Ridewise.',
        );
        expect(
          await write(
            model,
            index: 1,
            words: 20,
            previous: 'Money is a tool. It stores value.',
          ),
          'Save early.',
        );
        expect(
          await write(model, index: 2, words: 20, previous: 'Save early.'),
          "Start today. That's your Ridewise for this ride.",
        );

        expect(model.prompts[0], contains('This is the opening'));
        expect(model.prompts[0], contains('"What money is"'));
        expect(model.prompts[0], isNot(contains('so far ended')));
        expect(model.prompts[1], contains('This is a middle part'));
        expect(
          model.prompts[1],
          contains(
            'The talk so far ended with: "Money is a tool. It stores value."',
          ),
        );
        expect(model.prompts[2], contains('This is the final part'));
      },
    );

    test('a one-section talk is the whole talk', () async {
      final model = FakeModel(['All of it.']);
      await createScriptWriter(model).writeSection(
        request: request(),
        outline: const ScriptOutline(title: 'T', headings: ['Only']),
        index: 0,
        words: 20,
        previousText: '',
      );
      expect(model.prompts.single, contains('This is the whole talk'));
    });

    test(
      'asks for about the requested words and leaves the model room for them',
      () async {
        final model = FakeModel(['Text.']);
        await write(model, words: 200);

        // The first call is the section itself (a short reply then triggers one top-up call).
        expect(model.prompts.first, contains('about 200 words'));
        expect(model.maxTokens.first, 380); // 200 * 1.6 + 60
      },
    );

    test('uses the Hindi rule for hi-IN and cleans the model reply', () async {
      final model = FakeModel(['ज़रूर, यहाँ यह रहा:\n"नमस्ते दोस्तों।"']);
      final text = await write(model, language: CapsuleLanguage.hiIN);

      expect(model.prompts.first, contains('Devanagari'));
      expect(text, 'नमस्ते दोस्तों। यह है राइडवाइज़।');
    });

    test(
      'fails with scriptGenerationFailed when the model errors or the section is empty',
      () async {
        await expectLater(
          write(FakeModel([])),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
        await expectLater(
          write(FakeModel(['[music]'])),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
      },
    );
  });
}
