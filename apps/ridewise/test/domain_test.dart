import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/domain/text.dart';

void main() {
  group('calculateTargetSeconds', () {
    test('reserves a 10% buffer clamped to 60-180 seconds', () {
      expect(calculateTargetSeconds(1200), 1080);
      expect(calculateTargetSeconds(300), 240);
      expect(calculateTargetSeconds(3600), 3420);
    });

    test('never goes below 60 seconds', () {
      expect(calculateTargetSeconds(90), 60);
    });
  });

  group('splitIntoSegments', () {
    test('packs whole sentences up to the limit', () {
      expect(splitIntoSegments('One. Two. Three.', 10), [
        'One. Two.',
        'Three.',
      ]);
    });

    test('returns a single segment when everything fits', () {
      expect(splitIntoSegments('Only one sentence here.', 8000), [
        'Only one sentence here.',
      ]);
    });

    test('never splits inside an over-long sentence', () {
      final long = '${List.filled(20, 'word').join(' ')}.';
      expect(splitIntoSegments(long, 10), [long]);
    });

    test('returns an empty list for blank input', () {
      expect(splitIntoSegments('   ', 8000), isEmpty);
    });

    test('splits Hindi at the danda', () {
      expect(splitIntoSegments('यह पहला है। यह दूसरा है।', 12), [
        'यह पहला है।',
        'यह दूसरा है।',
      ]);
    });
  });

  group('withRetry', () {
    const tiny = Duration(milliseconds: 1);

    test('returns the first success without retrying', () async {
      var calls = 0;
      expect(await withRetry(() async => ++calls, baseDelay: tiny), 1);
      expect(calls, 1);
    });

    test('retries until it succeeds', () async {
      var calls = 0;
      final result = await withRetry(() async {
        if (++calls < 2) throw Exception('429');
        return 'ok';
      }, baseDelay: tiny);
      expect(result, 'ok');
      expect(calls, 2);
    });

    test('rethrows the last error once attempts are exhausted', () async {
      var calls = 0;
      await expectLater(
        withRetry<void>(() async {
          calls++;
          throw Exception('503');
        }, baseDelay: tiny),
        throwsA(predicate((e) => e.toString().contains('503'))),
      );
      expect(calls, 3);
    });
  });
}
