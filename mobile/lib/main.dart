import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fee_tables.dart';
import 'home_page.dart';
import 'palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Les tables d'optimisation sont calculées en arrière-plan dès le
  // lancement, pendant que l'utilisateur saisit son montant.
  final tables = FeeTables()..warmUp();
  runApp(MvolaSaveApp(tables: tables));
}

class MvolaSaveApp extends StatelessWidget {
  const MvolaSaveApp({super.key, required this.tables});

  final FeeTables tables;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MvolaSave',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Palette.light),
      darkTheme: buildTheme(Palette.dark),
      home: HomePage(tables: tables),
    );
  }
}
