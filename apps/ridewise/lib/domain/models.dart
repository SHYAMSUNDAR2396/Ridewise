/// Shared data types and the duration rule. Mirrors packages/domain (TypeScript).
library;

enum TransportMode {
  metro('metro', 'Metro'),
  bus('bus', 'Bus'),
  localTrain('local_train', 'Local train'),
  car('car', 'Cab or car'),
  bike('bike', 'Bike'),
  walk('walk', 'Walk'),
  other('other', 'Other');

  const TransportMode(this.wire, this.label);
  final String wire;
  final String label;

  static TransportMode fromWire(String wire) =>
      values.firstWhere((m) => m.wire == wire, orElse: () => other);
}

enum ListeningStyle {
  quickOverview('quick_overview', 'Quick overview'),
  learnDeeply('learn_deeply', 'Learn deeply');

  const ListeningStyle(this.wire, this.label);
  final String wire;
  final String label;
}

enum CapsuleLanguage {
  enIN('en-IN', 'English'),
  hiIN('hi-IN', 'Hindi');

  const CapsuleLanguage(this.code, this.label);
  final String code;
  final String label;

  static CapsuleLanguage fromCode(String code) =>
      values.firstWhere((l) => l.code == code, orElse: () => enIN);
}

/// The same stable codes the server API uses, so screens branch on one set.
enum CapsuleErrorCode {
  routeUnavailable,
  scriptGenerationFailed,
  speechSynthesisFailed,
  capsuleTooLong,
  audioUnavailable,
}

class GenerationException implements Exception {
  GenerationException(this.code, this.message);
  final CapsuleErrorCode code;
  final String message;

  @override
  String toString() => 'GenerationException(${code.name}): $message';
}

class TripDraft {
  const TripDraft({
    this.startLabel,
    this.endLabel,
    this.transportMode,
    this.estimatedSeconds,
    this.manualSeconds,
  });

  final String? startLabel;
  final String? endLabel;
  final TransportMode? transportMode;
  final int? estimatedSeconds;
  final int? manualSeconds;

  /// A user-entered time always wins over the route estimate.
  int? get tripSeconds => manualSeconds ?? estimatedSeconds;

  TripDraft copyWith({
    String? startLabel,
    String? endLabel,
    TransportMode? transportMode,
    int? estimatedSeconds,
    int? manualSeconds,
    bool clearManualSeconds = false,
  }) => TripDraft(
    startLabel: startLabel ?? this.startLabel,
    endLabel: endLabel ?? this.endLabel,
    transportMode: transportMode ?? this.transportMode,
    estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
    manualSeconds: clearManualSeconds
        ? null
        : (manualSeconds ?? this.manualSeconds),
  );

  Map<String, Object?> toJson() => {
    'startLabel': startLabel,
    'endLabel': endLabel,
    'transportMode': transportMode?.wire,
    if (estimatedSeconds != null) 'estimatedSeconds': estimatedSeconds,
    if (manualSeconds != null) 'manualSeconds': manualSeconds,
  };
}

class RouteEstimate {
  const RouteEstimate({required this.durationSeconds, required this.summary});
  final int durationSeconds;
  final String summary;

  factory RouteEstimate.fromJson(Map<String, Object?> json) => RouteEstimate(
    durationSeconds: (json['durationSeconds'] as num).toInt(),
    summary: json['summary'] as String? ?? '',
  );
}

class CreateCapsuleRequest {
  const CreateCapsuleRequest({
    required this.trip,
    required this.topic,
    required this.style,
    required this.language,
  });

  final TripDraft trip;
  final String topic;
  final ListeningStyle style;
  final CapsuleLanguage language;
}

class AudioSegment {
  const AudioSegment({
    required this.index,
    required this.url,
    required this.durationSeconds,
  });

  final int index;

  /// A `file://` URI for audio made on this phone, or an https URL.
  final String url;
  final double durationSeconds;

  Map<String, Object?> toJson() => {
    'index': index,
    'url': url,
    'durationSeconds': durationSeconds,
  };

  factory AudioSegment.fromJson(Map<String, Object?> json) => AudioSegment(
    index: (json['index'] as num).toInt(),
    url: json['url'] as String,
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
  );
}

class Capsule {
  const Capsule({
    required this.id,
    required this.title,
    required this.topic,
    required this.language,
    required this.targetSeconds,
    required this.audioSeconds,
    required this.transcript,
    required this.segments,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String topic;
  final CapsuleLanguage language;
  final int targetSeconds;
  final double audioSeconds;
  final String transcript;
  final List<AudioSegment> segments;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'topic': topic,
    'language': language.code,
    'targetSeconds': targetSeconds,
    'audioSeconds': audioSeconds,
    'transcript': transcript,
    'segments': [for (final s in segments) s.toJson()],
    'createdAt': createdAt.toIso8601String(),
  };

  factory Capsule.fromJson(Map<String, Object?> json) => Capsule(
    id: json['id'] as String,
    title: json['title'] as String,
    topic: json['topic'] as String,
    language: CapsuleLanguage.fromCode(json['language'] as String),
    targetSeconds: (json['targetSeconds'] as num).toInt(),
    audioSeconds: (json['audioSeconds'] as num).toDouble(),
    transcript: json['transcript'] as String,
    segments: [
      for (final s in json['segments'] as List<Object?>)
        AudioSegment.fromJson(s as Map<String, Object?>),
    ],
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Capsule length for a trip: leave an arrival buffer of 10% (60 to 180 seconds).
int calculateTargetSeconds(int tripSeconds) {
  final buffer = (tripSeconds * 0.1).round().clamp(60, 180);
  final target = tripSeconds - buffer;
  return target < 60 ? 60 : target;
}
