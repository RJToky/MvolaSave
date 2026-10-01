import 'package:flutter/foundation.dart';

import 'optimizer.dart';
import 'tariffs.dart';

/// Construit une fois, hors du fil d'interface, la table de chaque grille.
class FeeTables {
  final Map<Mode, Future<FeeTable>> _pending = {};
  final Map<Mode, FeeTable> _ready = {};

  void warmUp() {
    for (final mode in Mode.values) {
      get(mode);
    }
  }

  /// Table déjà prête, sans attente.
  FeeTable? ready(Mode mode) => _ready[mode];

  Future<FeeTable> get(Mode mode) => _pending[mode] ??= compute(
    _buildTable,
    mode,
    debugLabel: 'FeeTable',
  ).then((table) => _ready[mode] = table);
}

FeeTable _buildTable(Mode mode) => FeeTable.build(mode.tiers);
