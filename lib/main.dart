import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ui/component_gallery.dart';
import 'ui/theme.dart';

void main() {
  runApp(const BeeKasApp());
}

class BeeKasApp extends StatelessWidget {
  const BeeKasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeeKas',
      theme: beeTheme(),
      // Gallery is debug-only; real screens replace this in the login tickets.
      home: kDebugMode ? const ComponentGallery() : const Scaffold(),
    );
  }
}
