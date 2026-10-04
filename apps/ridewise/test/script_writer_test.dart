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

  group('createScriptWriter', () {
    test(
      'writes an outline, then one section at a time, carrying the last sentence forward',
      () async {
        final model = FakeModel([
          'Money Basics\nWhat money is\nSaving early',
          'Money is a tool. It stores value.',
          'Start saving early. Small amounts grow.',
        ]);

        final script = await createScriptWriter(
          model,
        ).write(request(words: 600));

        expect(script.title, 'Money Basics');
        expect(
          script.transcript,
          'Money is a tool. It stores value. Start saving early. Small amounts grow.',
        );
        expect(model.prompts, hasLength(3));
        expect(model.prompts[0], contains('exactly 2 lines'));
        expect(model.prompts[1], contains('This is the opening'));
        expect(model.prompts[2], contains('This is the final part'));
        expect(
          model.prompts[2],
          contains('The previous part ended with: "It stores value."'),
        );
        expect(model.prompts[0], contains('clear Indian English'));
      },
    );

    test(
      'asks for Devanagari Hindi and uses shorter sections for hi-IN',
      () async {
        final model = FakeModel([
          'शीर्षक\nपहला\nदूसरा',
          'यह पहला है।',
          'यह दूसरा है।',
        ]);

        final script = await createScriptWriter(
          model,
        ).write(request(words: 500, language: CapsuleLanguage.hiIN));

        expect(model.prompts[0], contains('exactly 2 lines')); // 500 / 250
        for (final prompt in model.prompts) {
          expect(prompt, contains('Devanagari'));
          expect(prompt, isNot(contains('Indian English')));
        }
        expect(script.transcript, 'यह पहला है। यह दूसरा है।');
      },
    );

    test(
      'fails with scriptGenerationFailed when the model errors or returns nothing',
      () async {
        Future<Script> write(List<String> replies) =>
            createScriptWriter(FakeModel(replies)).write(request());

        await expectLater(
          write([]),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
        await expectLater(
          write(['Title\nOne', '[music]']),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
        await expectLater(
          write(['  ']),
          failsWith(CapsuleErrorCode.scriptGenerationFailed),
        );
      },
    );
  });
}
