/// Optimisation des frais MVola : même algorithme que la version web.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'tariffs.dart';

/// Nombre maximal d'opérations proposées pour une même somme.
const int maxOperations = 10;

/// Tous les plafonds de tranches sont des multiples de 1 000 Ar : le calcul
/// travaille donc par unités de 1 000 Ar (20 000 unités au maximum).
const int unit = 1000;

const int _infinity = 1 << 30;
const int _size = maxAmount ~/ unit + 1;

class Operation {
  const Operation(this.amount, this.fee);

  final int amount;
  final int fee;
}

class OptimizationResult {
  const OptimizationResult({
    required this.amount,
    required this.normalFee,
    required this.optimizedFee,
    required this.operations,
  });

  final int amount;
  final int normalFee;
  final int optimizedFee;
  final List<Operation> operations;

  int get savings => normalFee - optimizedFee;
}

int? feeFor(int amount, List<Tier> tiers) {
  for (final t in tiers) {
    if (amount >= t.min && amount <= t.max) return t.fee;
  }
  return null;
}

/// Table de programmation dynamique d'une grille tarifaire.
///
/// Choisir une répartition revient à choisir une tranche par opération :
/// des tranches t1..tk permettent d'atteindre exactement un montant si et
/// seulement si  Σ min(ti) ≤ montant ≤ Σ max(ti).
///
/// La table résout la condition  Σ max(ti) ≥ montant  (problème de
/// « couverture », type rendu de monnaie) pour tous les montants possibles.
/// [optimize] garantit ensuite Σ min(ti) ≤ montant en rétrogradant des
/// tranches : les frais n'augmentent jamais (ils croissent avec la tranche)
/// et Σ max ≥ montant est conservé. Le coût trouvé est donc le minimum exact.
///
/// Elle ne dépend pas du montant saisi : elle est calculée une seule fois par
/// grille, après quoi chaque optimisation est instantanée.
class FeeTable {
  FeeTable._(this.tiers, this._cost, this._choice);

  final List<Tier> tiers;

  /// `_cost[(k - 1) * _size + c]` : frais minimum avec exactement k opérations
  /// dont les plafonds cumulés couvrent au moins c unités.
  final Int32List _cost;

  /// Tranche choisie pour la k-ième opération dans la case correspondante.
  final Int8List _choice;

  factory FeeTable.build(List<Tier> tiers) {
    final caps = Int32List.fromList([for (final t in tiers) t.max ~/ unit]);
    final fees = Int32List.fromList([for (final t in tiers) t.fee]);
    final cost = Int32List(maxOperations * _size);
    final choice = Int8List(maxOperations * _size);

    var prev = Int32List(_size)..fillRange(1, _size, _infinity);
    for (var k = 0; k < maxOperations; k++) {
      final row = k * _size;
      for (var c = 0; c < _size; c++) {
        var best = _infinity;
        var pick = -1;
        for (var i = 0; i < caps.length; i++) {
          final v = prev[c > caps[i] ? c - caps[i] : 0] + fees[i];
          if (v < best) {
            best = v;
            pick = i;
          }
        }
        cost[row + c] = best;
        choice[row + c] = pick;
      }
      prev = Int32List.sublistView(cost, row, row + _size);
    }
    return FeeTable._(tiers, cost, choice);
  }

  /// Répartition de [amount] en au plus [maxOperations] opérations dont le
  /// total des frais est minimal.
  OptimizationResult optimize(int amount) {
    final target = (amount + unit - 1) ~/ unit;

    // Inégalité stricte : à frais égaux, on garde le moins d'opérations.
    var bestCost = _infinity;
    var bestCount = 0;
    for (var k = 1; k <= maxOperations; k++) {
      final v = _cost[(k - 1) * _size + target];
      if (v < bestCost) {
        bestCost = v;
        bestCount = k;
      }
    }

    // Reconstitution des tranches choisies.
    final picked = <int>[];
    for (var k = bestCount, c = target; k >= 1; k--) {
      final i = _choice[(k - 1) * _size + c];
      picked.add(i);
      c = math.max(0, c - tiers[i].max ~/ unit);
    }

    // Garantit Σ min ≤ amount.
    var minSum = picked.fold(0, (s, i) => s + tiers[i].min);
    while (minSum > amount) {
      final pos = picked.indexOf(picked.reduce(math.max));
      if (picked[pos] > 0) {
        minSum -= tiers[picked[pos]].min - tiers[picked[pos] - 1].min;
        picked[pos] -= 1;
      } else {
        minSum -= tiers[0].min;
        picked.removeAt(pos);
      }
    }

    // Montants : chaque opération au plafond de sa tranche, puis on retire
    // l'excédent en commençant par les plus petites opérations.
    picked.sort((a, b) => b - a);
    final parts = [for (final i in picked) tiers[i].max];
    var excess = parts.fold(0, (s, p) => s + p) - amount;
    for (var j = parts.length - 1; j >= 0 && excess > 0; j--) {
      final cut = math.min(excess, parts[j] - tiers[picked[j]].min);
      parts[j] -= cut;
      excess -= cut;
    }

    final operations = [for (final p in parts) Operation(p, feeFor(p, tiers)!)]
      ..sort((a, b) => b.amount - a.amount);

    return OptimizationResult(
      amount: amount,
      normalFee: feeFor(amount, tiers)!,
      optimizedFee: operations.fold(0, (s, op) => s + op.fee),
      operations: operations,
    );
  }
}

/* ---------- Saisie et formatage ---------- */

final RegExp _groups = RegExp(r'\B(?=(\d{3})+(?!\d))');

String formatNumber(int value) => value.toString().replaceAll(_groups, ' ');

String formatAr(int value) => '${formatNumber(value)} Ar';

/// Résultat de la lecture du texte saisi : soit [value], soit [error].
class ParsedAmount {
  const ParsedAmount.value(int this.value) : error = null;
  const ParsedAmount.error(String this.error) : value = null;

  final int? value;
  final String? error;
}

final RegExp _spaces = RegExp(r'[\s  ]');
final RegExp _arSuffix = RegExp(r'ar$', caseSensitive: false);
final RegExp _digits = RegExp(r'^\d+$');
final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

ParsedAmount parseAmount(String? raw) {
  final text = (raw ?? '').replaceAll(_spaces, '').replaceFirst(_arSuffix, '');
  if (text.isEmpty) return const ParsedAmount.error('Veuillez saisir un montant.');
  if (!_digits.hasMatch(text)) {
    return const ParsedAmount.error('Utilisez uniquement des chiffres (montant entier en Ariary).');
  }
  // Plus de 9 chiffres significatifs dépasse forcément le maximum (et évite
  // tout débordement).
  final significant = text.replaceFirst(_leadingZeros, '');
  final value = significant.length > 9 ? maxAmount + 1 : int.parse(significant);
  if (value < minAmount) {
    return ParsedAmount.error('Le montant minimum est de ${formatAr(minAmount)}.');
  }
  if (value > maxAmount) {
    return ParsedAmount.error('Le montant maximum est de ${formatAr(maxAmount)}.');
  }
  return ParsedAmount.value(value);
}
