import 'package:flutter/material.dart';
import 'package:llamadart/llamadart.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  sherpa.initBindings();
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('sherpa ${sherpa.getVersion()} / ${LlamaEngine}'),
      ),
    ),
  ));
}
