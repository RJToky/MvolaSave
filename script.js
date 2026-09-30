/* MvolaSave — optimisation des frais MVola (transfert et retrait Cash Point). */

'use strict';

const MIN_AMOUNT = 100;
const MAX_AMOUNT = 20000000;

// Nombre maximal d'opérations proposées pour une même somme.
const MAX_OPERATIONS = 10;

// Tous les plafonds de tranches sont des multiples de 1 000 Ar : l'optimisation
// travaille donc par unités de 1 000 Ar (20 000 unités au maximum).
const UNIT = 1000;

// [minimum, maximum, frais] en Ariary.
const TARIFFS = {
  transfer: [
    [100, 1000, 70],
    [1001, 5000, 70],
    [5001, 10000, 150],
    [10001, 25000, 250],
    [25001, 50000, 500],
    [50001, 100000, 1000],
    [100001, 250000, 1900],
    [250001, 500000, 1900],
    [500001, 1000000, 3200],
    [1000001, 2000000, 3800],
    [2000001, 3000000, 5000],
    [3000001, 4000000, 6300],
    [4000001, 5000000, 7500],
    [5000001, 6000000, 9400],
    [6000001, 7000000, 10700],
    [7000001, 8000000, 12500],
    [8000001, 9000000, 14400],
    [9000001, 10000000, 15700],
    [10000001, 11000000, 17500],
    [11000001, 12000000, 18800],
    [12000001, 13000000, 20000],
    [13000001, 14000000, 21300],
    [14000001, 15000000, 23200],
    [15000001, 16000000, 25000],
    [16000001, 17000000, 26300],
    [17000001, 18000000, 28200],
    [18000001, 19000000, 30000],
    [19000001, 20000000, 31300],
  ],
  withdrawal: [
    [100, 1000, 100],
    [1001, 5000, 150],
    [5001, 10000, 275],
    [10001, 20000, 550],
    [20001, 25000, 650],
    [25001, 50000, 1300],
    [50001, 100000, 1900],
    [100001, 250000, 3400],
    [250001, 500000, 4700],
    [500001, 1000000, 8800],
    [1000001, 2000000, 14700],
    [2000001, 3000000, 19600],
    [3000001, 4000000, 24500],
    [4000001, 5000000, 29400],
    [5000001, 6000000, 34300],
    [6000001, 7000000, 39200],
    [7000001, 8000000, 44100],
    [8000001, 9000000, 49000],
    [9000001, 10000000, 53900],
    [10000001, 11000000, 59000],
    [11000001, 12000000, 64000],
    [12000001, 13000000, 69000],
    [13000001, 14000000, 74000],
    [14000001, 15000000, 79000],
    [15000001, 16000000, 84000],
    [16000001, 17000000, 89000],
    [17000001, 18000000, 94000],
    [18000001, 19000000, 98000],
    [19000001, 20000000, 100000],
  ],
};

const MODES = {
  transfer: {
    tiers: toTiers(TARIFFS.transfer),
    question: 'Combien voulez-vous transférer\u00a0?',
    operation: 'Transfert',
    normalLabel: 'Frais avec 1 transfert',
    alreadyOptimal: 'Un seul transfert est déjà l’option la moins chère.',
  },
  withdrawal: {
    tiers: toTiers(TARIFFS.withdrawal),
    question: 'Combien voulez-vous retirer\u00a0?',
    operation: 'Retrait',
    normalLabel: 'Frais avec 1 retrait',
    alreadyOptimal: 'Un seul retrait est déjà l’option la moins chère.',
  },
};

function toTiers(rows) {
  return rows.map(([min, max, fee]) => ({ min, max, fee }));
}

/* ---------- Calculs ---------- */

function feeFor(amount, tiers) {
  const tier = tiers.find((t) => amount >= t.min && amount <= t.max);
  return tier ? tier.fee : null;
}

/**
 * Cherche la répartition de `amount` en au plus MAX_OPERATIONS opérations
 * dont le total des frais est minimal.
 *
 * Choisir une répartition revient à choisir une tranche par opération :
 * des tranches t1..tk permettent d'atteindre exactement `amount` si et
 * seulement si  Σ min(ti) ≤ amount ≤ Σ max(ti).
 *
 * On résout d'abord la condition  Σ max(ti) ≥ amount  (problème de
 * « couverture », programmation dynamique type rendu de monnaie), puis on
 * garantit Σ min(ti) ≤ amount en rétrogradant des tranches : cela ne fait
 * jamais augmenter les frais (ils sont croissants avec la tranche) et
 * conserve Σ max ≥ amount. Le coût trouvé est donc bien le minimum exact.
 */
function optimize(amount, tiers) {
  const target = Math.ceil(amount / UNIT);
  const caps = tiers.map((t) => t.max / UNIT);
  const size = target + 1;

  // prev[c] : frais minimum avec exactement k-1 opérations dont les plafonds
  // cumulés couvrent au moins c unités.
  let prev = new Float64Array(size).fill(Infinity);
  prev[0] = 0;
  const choices = [];
  let bestCost = Infinity;
  let bestCount = 0;

  for (let k = 1; k <= MAX_OPERATIONS; k++) {
    const cur = new Float64Array(size).fill(Infinity);
    const choice = new Int8Array(size).fill(-1);
    for (let c = 0; c < size; c++) {
      for (let i = 0; i < tiers.length; i++) {
        const cost = prev[c > caps[i] ? c - caps[i] : 0] + tiers[i].fee;
        if (cost < cur[c]) {
          cur[c] = cost;
          choice[c] = i;
        }
      }
    }
    choices.push(choice);
    // Inégalité stricte : à frais égaux, on garde le moins d'opérations.
    if (cur[target] < bestCost) {
      bestCost = cur[target];
      bestCount = k;
    }
    prev = cur;
  }

  // Reconstitution des tranches choisies.
  const picked = [];
  for (let k = bestCount, c = target; k >= 1; k--) {
    const i = choices[k - 1][c];
    picked.push(i);
    c = Math.max(0, c - caps[i]);
  }

  // Garantit Σ min ≤ amount (voir commentaire ci-dessus).
  let minSum = picked.reduce((s, i) => s + tiers[i].min, 0);
  while (minSum > amount) {
    let pos = picked.indexOf(Math.max(...picked));
    if (picked[pos] > 0) {
      minSum -= tiers[picked[pos]].min - tiers[picked[pos] - 1].min;
      picked[pos] -= 1;
    } else {
      minSum -= tiers[0].min;
      picked.splice(pos, 1);
    }
  }

  // Montants : chaque opération au plafond de sa tranche, puis on retire
  // l'excédent en commençant par les plus petites opérations.
  picked.sort((a, b) => b - a);
  const parts = picked.map((i) => tiers[i].max);
  let excess = parts.reduce((s, p) => s + p, 0) - amount;
  for (let j = parts.length - 1; j >= 0 && excess > 0; j--) {
    const cut = Math.min(excess, parts[j] - tiers[picked[j]].min);
    parts[j] -= cut;
    excess -= cut;
  }

  const operations = parts
    .map((value) => ({ amount: value, fee: feeFor(value, tiers) }))
    .sort((a, b) => b.amount - a.amount);
  const optimizedFee = operations.reduce((s, op) => s + op.fee, 0);
  const normalFee = feeFor(amount, tiers);

  return {
    amount,
    normalFee,
    optimizedFee,
    savings: normalFee - optimizedFee,
    operations,
  };
}

/* ---------- Saisie et formatage ---------- */

function formatAr(value) {
  return formatNumber(value) + ' Ar';
}

function formatNumber(value) {
  return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

/** Retourne { value } ou { error } à partir du texte saisi. */
function parseAmount(raw) {
  const text = String(raw == null ? '' : raw)
    .replace(/[\s  ]/g, '')
    .replace(/ar$/i, '');
  if (text === '') return { error: 'Veuillez saisir un montant.' };
  if (!/^\d+$/.test(text)) return { error: 'Utilisez uniquement des chiffres (montant entier en Ariary).' };
  const value = Number(text);
  if (value < MIN_AMOUNT) return { error: 'Le montant minimum est de ' + formatAr(MIN_AMOUNT) + '.' };
  if (value > MAX_AMOUNT) return { error: 'Le montant maximum est de ' + formatAr(MAX_AMOUNT) + '.' };
  return { value };
}

/* ---------- Interface ---------- */

function initApp() {
  const $ = (id) => document.getElementById(id);
  const form = $('form');
  const input = $('amount');
  const question = $('question');
  const error = $('error');
  const result = $('result');
  const modeButtons = document.querySelectorAll('[data-mode]');
  let mode = 'transfer';

  modeButtons.forEach((button) => {
    button.addEventListener('click', () => setMode(button.dataset.mode));
  });

  // Formatage en direct : chiffres uniquement, groupés par milliers.
  input.addEventListener('input', () => {
    const caret = input.selectionStart;
    const digitsBeforeCaret = input.value.slice(0, caret).replace(/\D/g, '').length;
    const digits = input.value.replace(/\D/g, '').replace(/^0+(?=\d)/, '').slice(0, 8);
    input.value = formatNumber(digits);
    let pos = 0;
    for (let seen = 0; pos < input.value.length && seen < digitsBeforeCaret; pos++) {
      if (/\d/.test(input.value[pos])) seen++;
    }
    input.setSelectionRange(pos, pos);
    hideError();
  });

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    run(true);
  });

  function setMode(next) {
    mode = next;
    modeButtons.forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.mode === mode)));
    question.textContent = MODES[mode].question;
    renderTariffs();
    if (!result.hidden) run(false);
  }

  function run(focusOnError) {
    const parsed = parseAmount(input.value);
    if (parsed.error) {
      showError(parsed.error);
      result.hidden = true;
      if (focusOnError) input.focus();
      return;
    }
    hideError();
    renderResult(optimize(parsed.value, MODES[mode].tiers));
  }

  function renderResult(r) {
    const m = MODES[mode];
    $('r-amount').textContent = formatAr(r.amount);
    $('r-normal-label').textContent = m.normalLabel;
    $('r-normal').textContent = formatAr(r.normalFee);
    $('r-optimized').textContent = formatAr(r.optimizedFee);
    $('r-savings').textContent = formatAr(r.savings);
    $('r-savings-row').classList.toggle('is-zero', r.savings === 0);

    const note = $('r-note');
    note.hidden = r.savings > 0;
    note.textContent = m.alreadyOptimal;

    const list = $('r-operations');
    list.replaceChildren(
      ...r.operations.map((op, i) => {
        const li = document.createElement('li');
        li.innerHTML =
          '<span class="op-label">' + m.operation + ' ' + (i + 1) + '</span>' +
          '<span class="op-amount">' + formatAr(op.amount) + '</span>' +
          '<span class="op-fee">' + formatAr(op.fee) + '</span>';
        return li;
      })
    );
    $('r-total').textContent = formatAr(r.operations.reduce((s, op) => s + op.amount, 0));
    $('r-count').textContent = r.operations.length > 1 ? r.operations.length + ' opérations' : '1 opération';

    result.hidden = false;
  }

  function renderTariffs() {
    const rows = MODES[mode].tiers.map(
      (t) => '<tr><td>' + formatNumber(t.min) + ' – ' + formatNumber(t.max) + '</td><td>' + formatAr(t.fee) + '</td></tr>'
    );
    $('tariffs-title').textContent = mode === 'transfer' ? 'Transfert MVola → MVola' : 'Retrait Cash Point MVola';
    $('tariffs-body').innerHTML = rows.join('');
  }

  function showError(message) {
    error.textContent = message;
    error.hidden = false;
    input.setAttribute('aria-invalid', 'true');
  }

  function hideError() {
    error.hidden = true;
    input.removeAttribute('aria-invalid');
  }

  setMode(mode);
}

if (typeof document !== 'undefined') {
  document.addEventListener('DOMContentLoaded', initApp);
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TARIFFS, MODES, MAX_OPERATIONS, feeFor, optimize, parseAmount, formatAr };
}
