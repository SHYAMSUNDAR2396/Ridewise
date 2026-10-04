import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../generation/types.dart';
import 'capsule_store.dart';

/// Runs the on-device generation for the whole app, so it keeps going after the Topic screen is
/// closed. Every growing capsule is written into the [CapsuleStore]; screens only read from there.
class GenerationController extends ChangeNotifier {
  GenerationController({
    required GenerateCapsule generate,
    required CapsuleStore store,
  }) : _generate = generate,
       _store = store;

  final GenerateCapsule _generate;
  final CapsuleStore _store;

  StreamSubscription<CapsuleUpdate>? _sub;
  Completer<Capsule>? _first;
  bool _generating = false;
  GenerationProgress? _progress;
  String? _activeId;
  String? _notice;

  bool get isGenerating => _generating;
  GenerationProgress? get progress => _progress;

  /// The capsule being made, or the last one made until the next [start].
  String? get activeCapsuleId => _activeId;

  /// Set when a capsule ended early, for example because a later part failed.
  String? get notice => _notice;

  void dismissNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  /// Starts generating. The result completes with the FIRST playable capsule; later parts keep
  /// arriving in the store. Fails with the stream's error when nothing playable was produced.
  Future<Capsule> start(CreateCapsuleRequest request) {
    if (_generating) throw StateError('A capsule is already being generated.');
    _generating = true;
    _progress = null;
    _activeId = null;
    _notice = null;
    final first = _first = Completer<Capsule>();
    notifyListeners();

    _sub = _generate(request).listen(
      (update) {
        if (update.progress != null) _progress = update.progress;
        final capsule = update.capsule;
        if (capsule != null) {
          _store.upsert(capsule);
          _activeId = capsule.id;
          if (!first.isCompleted) first.complete(capsule);
        }
        if (update.complete) {
          _finish(update.notice);
        } else {
          notifyListeners();
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!first.isCompleted) {
          _finish(null);
          first.completeError(error, stack);
        } else {
          _finish("We couldn't finish the rest of this capsule.");
        }
      },
      onDone: () {
        if (!_generating) return;
        final made = first.isCompleted;
        _finish(null);
        if (!made) {
          first.completeError(
            GenerationException(
              CapsuleErrorCode.scriptGenerationFailed,
              "We couldn't make your capsule. Please try again.",
            ),
          );
        }
      },
    );
    return first.future;
  }

  /// Stops the work. Parts already made stay in the library.
  Future<void> cancel() async {
    if (!_generating) return;
    final sub = _sub;
    final first = _first;
    final made = first?.isCompleted ?? true;
    _finish(null);
    if (!made) {
      first!.completeError(
        GenerationException(
          CapsuleErrorCode.scriptGenerationFailed,
          'Generation was cancelled.',
        ),
      );
    }
    await sub?.cancel();
  }

  void _finish(String? notice) {
    _generating = false;
    _progress = null;
    _notice = notice;
    final stored = _store.byId(_activeId);
    if (stored != null && !stored.capsule.complete) {
      _store.upsert(stored.capsule.copyWith(complete: true));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
