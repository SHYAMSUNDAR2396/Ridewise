import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/capsule_store.dart';
import 'data/generation_controller.dart';
import 'data/now_playing.dart';
import 'data/trip_store.dart';
import 'playback/capsule_player.dart';
import 'theme.dart';
import 'ui/shell.dart';

/// Everything the screens read. Tests pass fakes for the API, generation and playback.
/// The [GenerationController] is app-level so a capsule keeps generating after its screen closes.
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.tripStore,
    required this.capsuleStore,
    required this.nowPlaying,
    required this.shell,
    required this.tripApi,
    required this.generation,
    required this.playback,
    required this.child,
  });

  final TripStore tripStore;
  final CapsuleStore capsuleStore;
  final NowPlaying nowPlaying;
  final ShellController shell;
  final TripApi tripApi;
  final GenerationController generation;
  final CapsulePlayback playback;
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: tripStore),
      ChangeNotifierProvider.value(value: capsuleStore),
      ChangeNotifierProvider.value(value: nowPlaying),
      ChangeNotifierProvider.value(value: shell),
      ChangeNotifierProvider<CapsulePlayback>.value(value: playback),
      Provider<TripApi>.value(value: tripApi),
      ChangeNotifierProvider.value(value: generation),
    ],
    child: child,
  );
}

class RidewiseApp extends StatelessWidget {
  const RidewiseApp({
    super.key,
    required this.tripStore,
    required this.capsuleStore,
    required this.nowPlaying,
    required this.shell,
    required this.tripApi,
    required this.generation,
    required this.playback,
  });

  final TripStore tripStore;
  final CapsuleStore capsuleStore;
  final NowPlaying nowPlaying;
  final ShellController shell;
  final TripApi tripApi;
  final GenerationController generation;
  final CapsulePlayback playback;

  @override
  Widget build(BuildContext context) => AppProviders(
    tripStore: tripStore,
    capsuleStore: capsuleStore,
    nowPlaying: nowPlaying,
    shell: shell,
    tripApi: tripApi,
    generation: generation,
    playback: playback,
    child: MaterialApp(
      title: 'Ridewise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    ),
  );
}
