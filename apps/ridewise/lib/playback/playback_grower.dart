import '../data/capsule_store.dart';
import 'capsule_player.dart';

/// Feeds new parts of the capsule being generated to the player. It lives at app level, like
/// [ProgressSaver], so playback keeps going after the player screen is closed.
class PlaybackGrower {
  PlaybackGrower(this._playback, this._store) {
    _store.addListener(_onChange);
  }

  final CapsulePlayback _playback;
  final CapsuleStore _store;

  void _onChange() {
    final loaded = _playback.capsule;
    if (loaded == null || loaded.complete) return;
    final latest = _store.byId(loaded.id)?.capsule;
    if (latest == null) return;
    if (latest.segments.length > loaded.segments.length ||
        (latest.complete && !loaded.complete)) {
      _playback.append(latest);
    }
  }

  void dispose() => _store.removeListener(_onChange);
}
