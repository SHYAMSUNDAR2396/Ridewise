import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'data/api_client.dart';
import 'data/capsule_store.dart';
import 'data/now_playing.dart';
import 'data/trip_store.dart';
import 'generation/native/runtime.dart';
import 'playback/capsule_player.dart';
import 'playback/progress_saver.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ridewise.ridewise.playback',
    androidNotificationChannelName: 'Ridewise playback',
    androidNotificationOngoing: true,
    fastForwardInterval: const Duration(seconds: 30),
    rewindInterval: const Duration(seconds: 10),
  );

  final capsuleStore = CapsuleStore();
  await capsuleStore.load();
  final playback = JustAudioCapsulePlayback();
  ProgressSaver(playback, capsuleStore);

  runApp(
    RidewiseApp(
      tripStore: TripStore(),
      capsuleStore: capsuleStore,
      nowPlaying: NowPlaying(),
      shell: ShellController(),
      tripApi: ApiClient(),
      generate: generateCapsuleOnDevice,
      playback: playback,
    ),
  );
}
