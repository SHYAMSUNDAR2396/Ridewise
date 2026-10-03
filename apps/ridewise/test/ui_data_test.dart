import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridewise/data/api_client.dart';
import 'package:ridewise/data/capsule_store.dart';
import 'package:ridewise/data/trip_store.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/playback/capsule_player.dart';
import 'package:ridewise/playback/progress_saver.dart';
import 'ui_support.dart';

void main() {
  group('CapsuleStore', () {
    test(
      'persists and reloads capsules with progress and saved state',
      () async {
        final storage = MemoryStorage();
        final first = CapsuleStore(storage: storage, deleteAudio: (_) async {});
        first.upsert(makeCapsule(id: 'a', title: 'First'));
        first.upsert(makeCapsule(id: 'b', title: 'Second'));
        first.setProgress('a', 125.5);
        first.toggleSaved('a');
        await first.flushed;

        final second = CapsuleStore(
          storage: storage,
          deleteAudio: (_) async {},
        );
        await second.load();

        expect(second.capsules.map((c) => c.id), ['b', 'a']);
        expect(second.byId('a')!.progressSeconds, 125.5);
        expect(second.byId('a')!.saved, isTrue);
        expect(second.byId('b')!.saved, isFalse);
        expect(
          second.byId('a')!.capsule.segments.single.url,
          'file:///docs/capsules/a/segment-0.wav',
        );
        expect(second.byId('a')!.capsule.language, CapsuleLanguage.enIN);
      },
    );

    test('starts empty when the library file is corrupt', () async {
      final storage = MemoryStorage()..data = '{not json';
      final store = CapsuleStore(storage: storage, deleteAudio: (_) async {});
      await store.load();
      expect(store.capsules, isEmpty);
    });

    test('remove deletes the audio and is persisted', () async {
      final storage = MemoryStorage();
      final deleted = <String>[];
      final store = CapsuleStore(
        storage: storage,
        deleteAudio: (c) async => deleted.add(c.id),
      );
      store.upsert(makeCapsule(id: 'a'));
      await store.remove('a');
      await store.flushed;

      expect(deleted, ['a']);
      expect((jsonDecode(storage.data!) as Map)['capsules'], isEmpty);
    });

    test('a failing audio delete does not stop removal', () async {
      final store = CapsuleStore(
        storage: MemoryStorage(),
        deleteAudio: (_) async => throw const FileSystemException('stuck'),
      );
      store.upsert(makeCapsule(id: 'a'));
      await store.remove('a');
      expect(store.capsules, isEmpty);
    });

    test(
      'deleteCapsuleAudio removes only a folder named after the capsule',
      () async {
        final root = await Directory.systemTemp.createTemp('ridewise_test');
        addTearDown(() => root.delete(recursive: true));

        Capsule capsuleIn(Directory dir, String id) => Capsule(
          id: id,
          title: 't',
          topic: 't',
          language: CapsuleLanguage.enIN,
          targetSeconds: 60,
          audioSeconds: 10,
          transcript: 't',
          segments: [
            AudioSegment(
              index: 0,
              url: dir.uri.resolve('segment-0.wav').toString(),
              durationSeconds: 10,
            ),
          ],
          createdAt: DateTime.utc(2026),
        );

        final own = await Directory(
          '${root.path}/capsules/cap-9',
        ).create(recursive: true);
        await File('${own.path}/segment-0.wav').writeAsString('x');
        await deleteCapsuleAudio(capsuleIn(own, 'cap-9'));
        expect(await own.exists(), isFalse);

        final other = await Directory(
          '${root.path}/precious',
        ).create(recursive: true);
        await File('${other.path}/segment-0.wav').writeAsString('x');
        await deleteCapsuleAudio(capsuleIn(other, 'cap-9'));
        expect(await other.exists(), isTrue);
      },
    );
  });

  group('TripStore', () {
    test('changing the route or mode drops a manual time', () {
      final store = TripStore()
        ..setEndpoints('A', 'B')
        ..setTransportMode(TransportMode.bus)
        ..setEstimatedSeconds(1200)
        ..setManualSeconds(900);
      expect(store.draft.tripSeconds, 900);

      store.setEndpoints('A', 'C');
      expect(store.draft.manualSeconds, isNull);
      expect(store.draft.tripSeconds, 1200);

      store.setManualSeconds(600);
      store.setTransportMode(TransportMode.metro);
      expect(store.draft.manualSeconds, isNull);
    });
  });

  group('ApiClient', () {
    test('posts the draft and parses the estimate', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            '{"durationSeconds":1080,"summary":"metro from A to B","source":"routing"}',
            200,
          );
        }),
      );

      final estimate = await client.estimateTrip(
        const TripDraft(
          startLabel: 'A',
          endLabel: 'B',
          transportMode: TransportMode.metro,
        ),
      );

      expect(estimate.durationSeconds, 1080);
      expect(seen.url.toString(), 'http://api.test/v1/trips/estimate');
      expect(jsonDecode(seen.body), containsPair('transportMode', 'metro'));
    });

    test('throws on an error response', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient(
          (_) async => http.Response('{"code":"ROUTE_UNAVAILABLE"}', 502),
        ),
      );
      await expectLater(
        client.estimateTrip(
          const TripDraft(
            startLabel: 'A',
            endLabel: 'B',
            transportMode: TransportMode.metro,
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)),
      );
    });
  });

  group('segmentAt', () {
    final segments = [
      const AudioSegment(index: 0, url: 'a', durationSeconds: 30),
      const AudioSegment(index: 1, url: 'b', durationSeconds: 30),
    ];

    test('maps a position to its segment and offset', () {
      expect(segmentAt(segments, 0), (index: 0, offsetSeconds: 0.0));
      expect(segmentAt(segments, 12), (index: 0, offsetSeconds: 12.0));
      expect(segmentAt(segments, 42), (index: 1, offsetSeconds: 12.0));
    });

    test('clamps past the end and handles no segments', () {
      expect(segmentAt(segments, 500), (index: 1, offsetSeconds: 30.0));
      expect(segmentAt(const [], 10), (index: 0, offsetSeconds: 0.0));
    });
  });

  group('ProgressSaver', () {
    test('saves every 10 seconds while playing and on pause', () async {
      final store = CapsuleStore(
        storage: MemoryStorage(),
        deleteAudio: (_) async {},
      );
      store.upsert(makeCapsule());
      final playback = FakePlayback();
      final saver = ProgressSaver(playback, store);
      addTearDown(saver.dispose);

      await playback.load(makeCapsule());
      await playback.play();

      playback.tick(4);
      expect(store.byId('cap-1')!.progressSeconds, 0);

      playback.tick(11);
      expect(store.byId('cap-1')!.progressSeconds, 11);

      playback.tick(15);
      expect(store.byId('cap-1')!.progressSeconds, 11);

      playback.tick(18);
      await playback.pause();
      expect(store.byId('cap-1')!.progressSeconds, 18);
    });
  });
}
