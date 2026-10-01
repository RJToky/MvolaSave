/// Grilles tarifaires MVola (en Ariary), identiques à la version web.
library;

const int minAmount = 100;
const int maxAmount = 20000000;

/// Une tranche : montant minimum, montant maximum et frais.
class Tier {
  const Tier(this.min, this.max, this.fee);

  final int min;
  final int max;
  final int fee;
}

enum Mode {
  transfer(
    tiers: transferTiers,
    question: 'Combien voulez-vous transférer ?',
    operation: 'Transfert',
    normalLabel: 'Frais avec 1 transfert',
    alreadyOptimal: 'Un seul transfert est déjà l’option la moins chère.',
    label: 'Transfert',
    tariffsTitle: 'Transfert MVola → MVola',
  ),
  withdrawal(
    tiers: withdrawalTiers,
    question: 'Combien voulez-vous retirer ?',
    operation: 'Retrait',
    normalLabel: 'Frais avec 1 retrait',
    alreadyOptimal: 'Un seul retrait est déjà l’option la moins chère.',
    label: 'Retrait',
    tariffsTitle: 'Retrait Cash Point MVola',
  );

  const Mode({
    required this.tiers,
    required this.question,
    required this.operation,
    required this.normalLabel,
    required this.alreadyOptimal,
    required this.label,
    required this.tariffsTitle,
  });

  final List<Tier> tiers;
  final String question;
  final String operation;
  final String normalLabel;
  final String alreadyOptimal;
  final String label;
  final String tariffsTitle;
}

const List<Tier> transferTiers = [
  Tier(100, 1000, 70),
  Tier(1001, 5000, 70),
  Tier(5001, 10000, 150),
  Tier(10001, 25000, 250),
  Tier(25001, 50000, 500),
  Tier(50001, 100000, 1000),
  Tier(100001, 250000, 1900),
  Tier(250001, 500000, 1900),
  Tier(500001, 1000000, 3200),
  Tier(1000001, 2000000, 3800),
  Tier(2000001, 3000000, 5000),
  Tier(3000001, 4000000, 6300),
  Tier(4000001, 5000000, 7500),
  Tier(5000001, 6000000, 9400),
  Tier(6000001, 7000000, 10700),
  Tier(7000001, 8000000, 12500),
  Tier(8000001, 9000000, 14400),
  Tier(9000001, 10000000, 15700),
  Tier(10000001, 11000000, 17500),
  Tier(11000001, 12000000, 18800),
  Tier(12000001, 13000000, 20000),
  Tier(13000001, 14000000, 21300),
  Tier(14000001, 15000000, 23200),
  Tier(15000001, 16000000, 25000),
  Tier(16000001, 17000000, 26300),
  Tier(17000001, 18000000, 28200),
  Tier(18000001, 19000000, 30000),
  Tier(19000001, 20000000, 31300),
];

const List<Tier> withdrawalTiers = [
  Tier(100, 1000, 100),
  Tier(1001, 5000, 150),
  Tier(5001, 10000, 275),
  Tier(10001, 20000, 550),
  Tier(20001, 25000, 650),
  Tier(25001, 50000, 1300),
  Tier(50001, 100000, 1900),
  Tier(100001, 250000, 3400),
  Tier(250001, 500000, 4700),
  Tier(500001, 1000000, 8800),
  Tier(1000001, 2000000, 14700),
  Tier(2000001, 3000000, 19600),
  Tier(3000001, 4000000, 24500),
  Tier(4000001, 5000000, 29400),
  Tier(5000001, 6000000, 34300),
  Tier(6000001, 7000000, 39200),
  Tier(7000001, 8000000, 44100),
  Tier(8000001, 9000000, 49000),
  Tier(9000001, 10000000, 53900),
  Tier(10000001, 11000000, 59000),
  Tier(11000001, 12000000, 64000),
  Tier(12000001, 13000000, 69000),
  Tier(13000001, 14000000, 74000),
  Tier(14000001, 15000000, 79000),
  Tier(15000001, 16000000, 84000),
  Tier(16000001, 17000000, 89000),
  Tier(17000001, 18000000, 94000),
  Tier(18000001, 19000000, 98000),
  Tier(19000001, 20000000, 100000),
];
