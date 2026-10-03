import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'player_screen.dart';

/// Opens Now Playing as a full-screen modal over the tab shell.
Future<void> openPlayer(BuildContext context, Capsule capsule) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlayerScreen(capsule: capsule),
      ),
    );
