import '../data/capsule_store.dart';
import 'capsule_player.dart';

/// Saves listening progress to the library: every 10 seconds while playing, and on pause.
/// It lives at app level so progress is kept even after the player screen is closed.
class ProgressSaver {
  ProgressSaver(this._playback, this._store, {this.interval = 10}) {
    _playback.addListener(_onChange);
  }

  final CapsulePlayback _playback;
  final CapsuleStore _store;
  final double interval;
  double _lastSaved = 0;
  bool _wasPlaying = false;
  String? _capsuleId;

  void _onChange() {
    final capsule = _playback.capsule;
    if (capsule == null) return;
    if (capsule.id != _capsuleId) {
      _capsuleId = capsule.id;
      _lastSaved = _playback.positionSeconds;
      _wasPlaying = _playback.playing;
      return;
    }
    final position = _playback.positionSeconds;
    final paused = _wasPlaying && !_playback.playing;
    _wasPlaying = _playback.playing;
    if (paused || (_playback.playing && position - _lastSaved >= interval)) {
      if (position > 0) {
        _lastSaved = position;
        _store.setProgress(capsule.id, position);
      }
    }
  }

  void dispose() => _playback.removeListener(_onChange);
}
