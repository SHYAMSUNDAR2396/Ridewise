import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/script_writer.dart';
import 'package:ridewise/generation/types.dart';

class FakeModel implements TextModel {
  FakeModel(this.replies);
  final List<String> replies;
  final prompts = <String>[];
  final maxTokens = <int>[];

  @override
  Future<String> complete(String prompt, {required int maxTokens}) async {
    prompts.add(prompt);
    this.maxTokens.add(maxTokens);
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

        expect(await write(model, index: 0), 'Money is a tool.');
        expect(
          await write(
            model,
            index: 1,
            previous: 'Money is a tool. It stores value.',
          ),
          'Save early.',
        );
        expect(
          await write(model, index: 2, previous: 'Save early.'),
          'Start today.',
        );

        expect(model.prompts[0], contains('This is the opening'));
        expect(model.prompts[0], contains('"What money is"'));
        expect(model.prompts[0], isNot(contains('previous part ended')));
        expect(model.prompts[1], contains('This is a middle part'));
        expect(
          model.prompts[1],
          contains('The previous part ended with: "It stores value."'),
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
        words: 80,
        previousText: '',
      );
      expect(model.prompts.single, contains('This is the whole talk'));
    });

    test(
      'asks for about the requested words and leaves the model room for them',
      () async {
        final model = FakeModel(['Text.']);
        await write(model, words: 200);

        expect(model.prompts.single, contains('about 200 words'));
        expect(model.maxTokens.single, 380); // 200 * 1.6 + 60
      },
    );

    test('uses the Hindi rule for hi-IN and cleans the model reply', () async {
      final model = FakeModel(['ज़रूर, यहाँ यह रहा:\n"नमस्ते दोस्तों।"']);
      final text = await write(model, language: CapsuleLanguage.hiIN);

      expect(model.prompts.single, contains('Devanagari'));
      expect(text, 'नमस्ते दोस्तों।');
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
