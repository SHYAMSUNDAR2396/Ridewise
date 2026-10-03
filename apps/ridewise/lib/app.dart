import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/capsule_store.dart';
import 'data/now_playing.dart';
import 'data/trip_store.dart';
import 'generation/types.dart';
import 'playback/capsule_player.dart';
import 'theme.dart';
import 'ui/shell.dart';

/// Everything the screens read. Tests pass fakes for the API, generation and playback.
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.tripStore,
    required this.capsuleStore,
    required this.nowPlaying,
    required this.shell,
    required this.tripApi,
    required this.generate,
    required this.playback,
    required this.child,
  });

  final TripStore tripStore;
  final CapsuleStore capsuleStore;
  final NowPlaying nowPlaying;
  final ShellController shell;
  final TripApi tripApi;
  final GenerateCapsule generate;
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
      Provider<GenerateCapsule>.value(value: generate),
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
    required this.generate,
    required this.playback,
  });

  final TripStore tripStore;
  final CapsuleStore capsuleStore;
  final NowPlaying nowPlaying;
  final ShellController shell;
  final TripApi tripApi;
  final GenerateCapsule generate;
  final CapsulePlayback playback;

  @override
  Widget build(BuildContext context) => AppProviders(
    tripStore: tripStore,
    capsuleStore: capsuleStore,
    nowPlaying: nowPlaying,
    shell: shell,
    tripApi: tripApi,
    generate: generate,
    playback: playback,
    child: MaterialApp(
      title: 'Ridewise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    ),
  );
}
