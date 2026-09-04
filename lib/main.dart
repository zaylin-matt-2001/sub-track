import 'package:flutter/material.dart';

void main() {
  runApp(const SubTrackApp());
}

class SubTrackApp extends StatelessWidget {
  const SubTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme:
          ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.indigo),
      home: const Scaffold(
        body: Center(child: Text('SubTrack')),
      ),
    );
  }
}
