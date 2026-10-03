import '../../domain/models.dart';
import '../types.dart';

/// Placeholder until the native adapters land: Gemma writes the script, Kokoro speaks it.
Future<Capsule> generateCapsuleOnDevice(
  CreateCapsuleRequest request,
  ProgressCallback onProgress,
) =>
    throw UnimplementedError('on-device generation is not wired yet');
