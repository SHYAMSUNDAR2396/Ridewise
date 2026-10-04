import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../domain/models.dart';

/// Maps a position in the whole capsule to the segment holding it and the offset inside it.
({int index, double offsetSeconds}) segmentAt(
  List<AudioSegment> segments,
  double positionSeconds,
) {
  if (segments.isEmpty || positionSeconds <= 0) {
    return (index: 0, offsetSeconds: 0);
  }
  var remaining = positionSeconds;
  for (var i = 0; i < segments.length; i++) {
    if (remaining < segments[i].durationSeconds) {
      return (index: i, offsetSeconds: remaining);
    }
    remaining -= segments[i].durationSeconds;
  }
  return (
    index: segments.length - 1,
    offsetSeconds: segments.last.durationSeconds,
  );
}

/// Plays one capsule's ordered segments as a single timeline. The UI depends on this
/// interface so widget tests can use a fake.
abstract class CapsulePlayback extends ChangeNotifier {
  Capsule? get capsule;
  bool get playing;

  /// Seconds into the whole capsule, across segments.
  double get positionSeconds;
  double get durationSeconds;

  /// True when the audio could not be loaded or played.
  bool get hasError;

  /// True when playback ran out of audio while the capsule is still being generated. It resumes
  /// by itself when the next part is appended.
  bool get waitingForMore;

  /// Loads [capsule] paused at [startSeconds]. Reloads when it is already loaded (used by Retry).
  Future<void> load(Capsule capsule, {double startSeconds = 0});

  /// Adds the segments of [grown] that are not loaded yet to the end of the timeline.
  /// [grown] is the same capsule as the loaded one with more parts, or the same parts marked complete.
  Future<void> append(Capsule grown);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(double seconds);
  Future<void> seekBy(double seconds) => seekTo(positionSeconds + seconds);
}

class JustAudioCapsulePlayback extends CapsulePlayback {
  JustAudioCapsulePlayback({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subs
      ..add(
        _player.positionStream.listen((p) {
          _segmentPosition = p;
          notifyListeners();
        }),
      )
      ..add(
        _player.currentIndexStream.listen((i) {
          _index = i ?? 0;
          notifyListeners();
        }),
      )
      ..add(
        _player.playerStateStream.listen((s) {
          final ended = s.processingState == ProcessingState.completed;
          _playing = s.playing && !ended;
          if (ended && !_waiting && !(_capsule?.complete ?? true)) {
            // Out of audio but more is coming: stay paused here and resume on append.
            _waiting = true;
            unawaited(_player.pause());
          }
          notifyListeners();
        }),
      )
      ..add(
        _player.playbackEventStream.listen(
          (_) {},
          onError: (Object _, StackTrace _) {
            _error = true;
            notifyListeners();
          },
        ),
      );
  }

  final AudioPlayer _player;
  final _subs = <StreamSubscription<Object?>>[];
  Capsule? _capsule;
  Duration _segmentPosition = Duration.zero;
  int _index = 0;
  int _loadedCount = 0;
  bool _playing = false;
  bool _error = false;
  bool _waiting = false;

  @override
  Capsule? get capsule => _capsule;
  @override
  bool get playing => _playing;
  @override
  bool get hasError => _error;
  @override
  bool get waitingForMore => _waiting;
  @override
  double get durationSeconds => _capsule?.audioSeconds ?? 0;

  @override
  double get positionSeconds {
    final segments = _capsule?.segments ?? const <AudioSegment>[];
    var before = 0.0;
    for (var i = 0; i < _index && i < segments.length; i++) {
      before += segments[i].durationSeconds;
    }
    return before + _segmentPosition.inMilliseconds / 1000;
  }

  @override
  Future<void> load(Capsule capsule, {double startSeconds = 0}) async {
    _capsule = capsule;
    _error = false;
    _waiting = false;
    _loadedCount = capsule.segments.length;
    final start = segmentAt(capsule.segments, startSeconds);
    try {
      await _player.setAudioSources(
        [for (final s in capsule.segments) _source(capsule, s)],
        initialIndex: start.index,
        initialPosition: Duration(
          milliseconds: (start.offsetSeconds * 1000).round(),
        ),
      );
    } catch (_) {
      _error = true;
    }
    notifyListeners();
  }

  AudioSource _source(Capsule capsule, AudioSegment s) => AudioSource.uri(
    Uri.parse(s.url),
    tag: MediaItem(id: s.url, title: capsule.title, album: capsule.topic),
  );

  @override
  Future<void> append(Capsule grown) async {
    final current = _capsule;
    if (current == null || current.id != grown.id) return;
    // Set first so a second call while this one awaits sees the new state.
    _capsule = grown;
    final first = _loadedCount;
    final fresh = grown.segments.skip(first).toList();
    _loadedCount = first + fresh.length;
    if (fresh.isNotEmpty) {
      try {
        await _player.addAudioSources([
          for (final s in fresh) _source(grown, s),
        ]);
      } catch (_) {
        _error = true;
      }
    }
    if (_waiting && fresh.isNotEmpty) {
      _waiting = false;
      await _player.seek(Duration.zero, index: first);
      unawaited(_player.play());
    } else if (_waiting && grown.complete) {
      _waiting = false; // Nothing more is coming: playback simply ends.
    }
    notifyListeners();
  }

  @override
  Future<void> play() async {
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(double seconds) async {
    final capsule = _capsule;
    if (capsule == null) return;
    final target = segmentAt(
      capsule.segments,
      seconds.clamp(0, capsule.audioSeconds).toDouble(),
    );
    await _player.seek(
      Duration(milliseconds: (target.offsetSeconds * 1000).round()),
      index: target.index,
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
