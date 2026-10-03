import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/app.dart';
import 'package:ridewise/data/api_client.dart';
import 'package:ridewise/data/capsule_store.dart';
import 'package:ridewise/data/now_playing.dart';
import 'package:ridewise/data/trip_store.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/types.dart';
import 'package:ridewise/playback/capsule_player.dart';
import 'package:ridewise/theme.dart';
import 'package:ridewise/ui/shell.dart';

class MemoryStorage implements CapsuleStorage {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async => data = d;
}

class FakeTripApi implements TripApi {
  FakeTripApi([this.handler]);
  Future<RouteEstimate> Function(TripDraft)? handler;
  int calls = 0;

  @override
  Future<RouteEstimate> estimateTrip(TripDraft draft) {
    calls++;
    return handler?.call(draft) ??
        Future.value(
          const RouteEstimate(durationSeconds: 1080, summary: 'metro'),
        );
  }
}

class FakePlayback extends CapsulePlayback {
  Capsule? _capsule;
  bool _playing = false;
  bool _error = false;
  double position = 0;
  final loads = <({Capsule capsule, double start})>[];
  int plays = 0;
  int pauses = 0;
  final seeks = <double>[];

  @override
  Capsule? get capsule => _capsule;
  @override
  bool get playing => _playing;
  @override
  double get positionSeconds => position;
  @override
  double get durationSeconds => _capsule?.audioSeconds ?? 0;
  @override
  bool get hasError => _error;

  set error(bool v) {
    _error = v;
    notifyListeners();
  }

  @override
  Future<void> load(Capsule capsule, {double startSeconds = 0}) async {
    loads.add((capsule: capsule, start: startSeconds));
    _capsule = capsule;
    position = startSeconds;
    _error = false;
    notifyListeners();
  }

  /// Moves the playhead and tells listeners, like a playing player would.
  void tick(double seconds) {
    position = seconds;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    plays++;
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauses++;
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(double seconds) async {
    seeks.add(seconds);
    position = seconds;
    notifyListeners();
  }
}

Capsule makeCapsule({
  String id = 'cap-1',
  String title = 'Index Funds, Explained',
  String topic = 'Personal finance',
  double audioSeconds = 2100,
  CapsuleLanguage language = CapsuleLanguage.enIN,
}) => Capsule(
  id: id,
  title: title,
  topic: topic,
  language: language,
  targetSeconds: 2100,
  audioSeconds: audioSeconds,
  transcript: 'The transcript of $title.',
  segments: [
    AudioSegment(
      index: 0,
      url: 'file:///docs/capsules/$id/segment-0.wav',
      durationSeconds: audioSeconds,
    ),
  ],
  createdAt: DateTime.utc(2026, 10, 3),
);

/// Wires every provider to fakes and builds the app around a screen.
class TestEnv {
  TestEnv({GenerateCapsule? generate})
    : generate = generate ?? ((_, _) async => makeCapsule()) {
    store = CapsuleStore(
      storage: storage,
      deleteAudio: (c) async => deleted.add(c.id),
    );
  }

  final storage = MemoryStorage();
  final deleted = <String>[];
  late final CapsuleStore store;
  final trips = TripStore();
  final nowPlaying = NowPlaying();
  final shell = ShellController();
  final api = FakeTripApi();
  final playback = FakePlayback();
  GenerateCapsule generate;

  Widget app(Widget home) => AppProviders(
    tripStore: trips,
    capsuleStore: store,
    nowPlaying: nowPlaying,
    shell: shell,
    tripApi: api,
    generate: (r, p) => generate(r, p),
    playback: playback,
    child: MaterialApp(theme: buildTheme(), home: home),
  );
}

/// A phone-sized surface so screens do not overflow the 800x600 test default.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
