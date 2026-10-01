import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvolasave/home_page.dart';
import 'package:mvolasave/optimizer.dart';
import 'package:mvolasave/tariffs.dart';

/// Frais minimum exacts, au franc près, pour tous les montants ≤ [limit]
/// (programmation dynamique sur le montant, fenêtre glissante par tranche).
Float64List bruteForce(List<Tier> tiers, int limit) {
  var prev = Float64List(limit + 1)..fillRange(1, limit + 1, double.infinity);
  final best = Float64List(limit + 1)..fillRange(0, limit + 1, double.infinity);
  for (var k = 1; k <= maxOperations; k++) {
    final cur = Float64List(limit + 1)..fillRange(0, limit + 1, double.infinity);
    for (final t in tiers) {
      if (t.min > limit) break;
      final dq = List<int>.filled(limit + 1, 0);
      var head = 0, tail = 0;
      for (var n = t.min; n <= limit; n++) {
        final add = n - t.min;
        while (tail > head && prev[dq[tail - 1]] >= prev[add]) {
          tail--;
        }
        dq[tail++] = add;
        while (dq[head] < n - t.max) {
          head++;
        }
        final v = prev[dq[head]] + t.fee;
        if (v < cur[n]) cur[n] = v;
      }
    }
    for (var n = 0; n <= limit; n++) {
      if (cur[n] < best[n]) best[n] = cur[n];
    }
    prev = cur;
  }
  return best;
}

/// Meilleur coût parmi toutes les combinaisons de tranches de ≤ [k] opérations.
int enumerate(int amount, List<Tier> tiers, int k) {
  var best = 1 << 30;
  void rec(int start, int depth, int lo, int hi, int fee) {
    if (lo > amount) return;
    if (depth > 0 && hi >= amount && fee < best) best = fee;
    if (depth == k) return;
    for (var i = start; i < tiers.length; i++) {
      rec(i, depth + 1, lo + tiers[i].min, hi + tiers[i].max, fee + tiers[i].fee);
    }
  }

  rec(0, 0, 0, 0, 0);
  return best;
}

void checkResult(OptimizationResult r, int amount, List<Tier> tiers) {
  expect(r.operations.fold(0, (s, op) => s + op.amount), amount);
  expect(r.operations.length, inInclusiveRange(1, maxOperations));
  for (final op in r.operations) {
    expect(op.amount, inInclusiveRange(minAmount, maxAmount));
    expect(op.fee, feeFor(op.amount, tiers));
  }
  expect(r.optimizedFee, r.operations.fold(0, (s, op) => s + op.fee));
  expect(r.optimizedFee, lessThanOrEqualTo(r.normalFee));
}

void main() {
  final tables = {for (final m in Mode.values) m: FeeTable.build(m.tiers)};
  final random = Random(42);

  test('grilles contiguës, plafonds multiples de 1 000, frais croissants', () {
    for (final m in Mode.values) {
      final t = m.tiers;
      expect(t.first.min, minAmount);
      expect(t.last.max, maxAmount);
      for (var i = 0; i < t.length; i++) {
        expect(t[i].max % unit, 0);
        if (i > 0) {
          expect(t[i].min, t[i - 1].max + 1);
          expect(t[i].fee, greaterThanOrEqualTo(t[i - 1].fee));
        }
      }
    }
  });

  for (final m in Mode.values) {
    test('${m.name} : minimum exact face à la force brute', () {
      const limit = 120000;
      final exact = bruteForce(m.tiers, limit);
      final amounts = [
        for (var n = minAmount; n <= 25000; n++) n,
        for (var i = 0; i < 5000; i++) minAmount + random.nextInt(limit - minAmount + 1),
      ];
      for (final n in amounts) {
        final r = tables[m]!.optimize(n);
        checkResult(r, n, m.tiers);
        expect(r.optimizedFee, exact[n].toInt(), reason: '${m.name} $n');
      }
    });

    test('${m.name} : grands montants et limites de tranches', () {
      final amounts = <int>{
        for (final t in [...transferTiers, ...withdrawalTiers]) ...[
          t.min - 1,
          t.min,
          t.max,
          t.max + 1,
        ],
        for (var i = 0; i < 300; i++) minAmount + random.nextInt(maxAmount - minAmount + 1),
      }.where((n) => n >= minAmount && n <= maxAmount);
      for (final n in amounts) {
        final r = tables[m]!.optimize(n);
        checkResult(r, n, m.tiers);
        expect(r.optimizedFee, lessThanOrEqualTo(enumerate(n, m.tiers, 3)), reason: '${m.name} $n');
      }
    });
  }

  test('mêmes résultats que la version web', () {
    final transfer = tables[Mode.transfer]!;
    final withdrawal = tables[Mode.withdrawal]!;
    String parts(OptimizationResult r) =>
        r.operations.map((o) => '${o.amount}→${o.fee}').join(' + ');

    expect(parts(transfer.optimize(1000000)), '1000000→3200');
    expect(parts(withdrawal.optimize(1000000)), '1000000→8800');
    expect(parts(transfer.optimize(510000)), '500000→1900 + 5000→70 + 5000→70');
    expect(parts(withdrawal.optimize(510000)), '500000→4700 + 10000→275');
    expect(parts(transfer.optimize(6000)), '5000→70 + 1000→70');
    expect(parts(transfer.optimize(20000000)), List.filled(4, '5000000→7500').join(' + '));
    expect(parts(withdrawal.optimize(5000001)), '4999901→29400 + 100→100');
    expect(transfer.optimize(510000).savings, 1160);
  });

  test('lecture du montant saisi', () {
    for (final bad in [
      null,
      '',
      '   ',
      'abc',
      '12a3',
      '1000,5',
      '-500',
      '99',
      '20000001',
      '9999999999999',
    ]) {
      expect(parseAmount(bad).error, isNotNull, reason: '$bad');
    }
    expect(parseAmount('100').value, 100);
    expect(parseAmount('20 000 000').value, 20000000);
    expect(parseAmount('1 000 000 Ar').value, 1000000);
    expect(parseAmount('00150').value, 150);
    expect(parseAmount('0000000000150').value, 150);
    expect(formatAr(1000000), '1 000 000 Ar');
  });

  test('formatage pendant la saisie', () {
    const f = AmountInputFormatter();
    TextEditingValue type(String old, String text, int caret) => f.formatEditUpdate(
      TextEditingValue(text: old),
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
      ),
    );

    expect(type('51 000', '510 000', 3).text, '510 000');
    expect(type('', '12a3', 4).text, '123');
    expect(type('', '000150', 6).text, '150');
    expect(type('', '123456789', 9).text, '12 345 678');
    // Effacer l'espace de « 12 345 » efface le « 2 » qui le précède.
    final v = type('12\u00a0345', '12345', 2);
    expect(v.text, '1\u00a0345');
    expect(v.selection.end, 1);
  });
}
