import 'package:flutter/foundation.dart';
import '../domain/models.dart';

/// The trip being planned. Changing the route or mode drops a manual time.
class TripStore extends ChangeNotifier {
  TripDraft _draft = const TripDraft();
  TripDraft get draft => _draft;

  void setEndpoints(String start, String end) {
    _draft = _draft.copyWith(
      startLabel: start,
      endLabel: end,
      clearManualSeconds: true,
    );
    notifyListeners();
  }

  void setTransportMode(TransportMode mode) {
    _draft = _draft.copyWith(transportMode: mode, clearManualSeconds: true);
    notifyListeners();
  }

  void setManualSeconds(int seconds) {
    _draft = _draft.copyWith(manualSeconds: seconds);
    notifyListeners();
  }

  void setEstimatedSeconds(int seconds) {
    _draft = _draft.copyWith(estimatedSeconds: seconds);
    notifyListeners();
  }
}
