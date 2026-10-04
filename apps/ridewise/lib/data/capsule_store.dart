import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models.dart';

/// A capsule in the local library plus per-device state.
class StoredCapsule {
  const StoredCapsule(
    this.capsule, {
    this.progressSeconds = 0,
    this.saved = false,
  });

  final Capsule capsule;
  final double progressSeconds;
  final bool saved;

  String get id => capsule.id;

  StoredCapsule copyWith({double? progressSeconds, bool? saved}) =>
      StoredCapsule(
        capsule,
        progressSeconds: progressSeconds ?? this.progressSeconds,
        saved: saved ?? this.saved,
      );

  StoredCapsule _finished() => capsule.complete
      ? this
      : StoredCapsule(
          capsule.copyWith(complete: true),
          progressSeconds: progressSeconds,
          saved: saved,
        );

  Map<String, Object?> toJson() => {
    ...capsule.toJson(),
    'progressSeconds': progressSeconds,
    'saved': saved,
  };

  factory StoredCapsule.fromJson(Map<String, Object?> json) => StoredCapsule(
    Capsule.fromJson(json),
    progressSeconds: (json['progressSeconds'] as num?)?.toDouble() ?? 0,
    saved: json['saved'] as bool? ?? false,
  );
}

abstract interface class CapsuleStorage {
  Future<String?> read();
  Future<void> write(String data);
}

class FileCapsuleStorage implements CapsuleStorage {
  Future<File> _file() async => File(
    '${(await getApplicationDocumentsDirectory()).path}/capsule_library.json',
  );

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String data) async =>
      (await _file()).writeAsString(data, flush: true);
}

typedef DeleteAudio = Future<void> Function(Capsule capsule);

/// Deletes the folder holding a capsule's WAV files. Only a folder named after the capsule id is removed.
Future<void> deleteCapsuleAudio(Capsule capsule) async {
  for (final segment in capsule.segments) {
    if (!segment.url.startsWith('file://')) continue;
    final dir = File(Uri.parse(segment.url).toFilePath()).parent;
    if (dir.uri.pathSegments.where((s) => s.isNotEmpty).last == capsule.id &&
        await dir.exists()) {
      await dir.delete(recursive: true);
    }
    return;
  }
}

/// The local library, newest first. Capsules are always local audio, so there is no download state.
class CapsuleStore extends ChangeNotifier {
  CapsuleStore({CapsuleStorage? storage, DeleteAudio? deleteAudio})
    : _storage = storage ?? FileCapsuleStorage(),
      _deleteAudio = deleteAudio ?? deleteCapsuleAudio;

  final CapsuleStorage _storage;
  final DeleteAudio _deleteAudio;
  List<StoredCapsule> _items = const [];
  Future<void> _writes = Future.value();

  List<StoredCapsule> get capsules => _items;

  StoredCapsule? byId(String? id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw == null) return;
      final list =
          (jsonDecode(raw) as Map<String, Object?>)['capsules']
              as List<Object?>;
      _items = [
        for (final j in list)
          // Generation cannot survive an app restart, so a half-made capsule is as complete as it will get.
          StoredCapsule.fromJson(j as Map<String, Object?>)._finished(),
      ];
      notifyListeners();
    } catch (_) {
      // A corrupt library file must not stop the app; start empty.
      _items = const [];
    }
  }

  /// Adds a capsule at the top, or replaces an existing one's audio and text (it grows part by part),
  /// keeping its progress and saved state.
  void upsert(Capsule capsule) {
    final existing = byId(capsule.id);
    _items = [
      StoredCapsule(
        capsule,
        progressSeconds: existing?.progressSeconds ?? 0,
        saved: existing?.saved ?? false,
      ),
      ..._items.where((i) => i.id != capsule.id),
    ];
    _changed();
  }

  void setProgress(String id, double seconds) =>
      _update(id, (i) => i.copyWith(progressSeconds: seconds));

  void toggleSaved(String id) =>
      _update(id, (i) => i.copyWith(saved: !i.saved));

  Future<void> remove(String id) async {
    final item = byId(id);
    if (item == null) return;
    _items = _items.where((i) => i.id != id).toList();
    _changed();
    try {
      await _deleteAudio(item.capsule);
    } catch (_) {
      // Best effort: a stuck file must not block removing the row.
    }
  }

  void _update(String id, StoredCapsule Function(StoredCapsule) change) {
    if (byId(id) == null) return;
    _items = [for (final i in _items) i.id == id ? change(i) : i];
    _changed();
  }

  void _changed() {
    notifyListeners();
    final data = jsonEncode({
      'capsules': [for (final i in _items) i.toJson()],
    });
    _writes = _writes
        .then((_) => _storage.write(data))
        .catchError((Object _) {});
  }

  /// Completes when all queued writes have finished (for tests).
  @visibleForTesting
  Future<void> get flushed => _writes;
}
