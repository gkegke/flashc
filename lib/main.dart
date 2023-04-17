
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'widgets/themes.dart';
import 'widgets/home.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(700, 350),
    backgroundColor: Colors.transparent,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flashc',
      theme: BaseTheme.light(),
      home: const Home(),
    );
  }
}
