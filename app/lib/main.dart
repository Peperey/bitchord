import 'package:flutter/material.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitchord',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.purple),
      home: const Scaffold(
        body: Center(child: Text('Bitchord v0.1')),
      ),
    );
  }
}
