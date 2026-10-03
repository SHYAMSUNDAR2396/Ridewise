import 'package:flutter/foundation.dart';

/// Which capsule the mini player shows.
class NowPlaying extends ChangeNotifier {
  String? _capsuleId;
  String? get capsuleId => _capsuleId;

  void set(String? id) {
    if (id == _capsuleId) return;
    _capsuleId = id;
    notifyListeners();
  }
}
