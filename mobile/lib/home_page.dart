import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fee_tables.dart';
import 'optimizer.dart';
import 'palette.dart';
import 'tariffs.dart';

const Duration _fast = Duration(milliseconds: 220);
const Curve _curve = Curves.easeOutCubic;

/// Durée du glissement du sélecteur Transfert / Retrait : courte et réactive.
const Duration _switch = Duration(milliseconds: 150);

/// Largeur à partir de laquelle le résultat s'affiche à côté du formulaire.
const double _twoColumnWidth = 760;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.tables});

  final FeeTables tables;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _resultKey = GlobalKey();

  Mode _mode = Mode.transfer;
  OptimizationResult? _result;
  String? _error;
  int _runToken = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setMode(Mode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    if (_result != null) _run(fromSubmit: false);
  }

  void _onChanged(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _run({required bool fromSubmit}) async {
    final token = ++_runToken;
    final parsed = parseAmount(_controller.text);
    if (parsed.error != null) {
      setState(() {
        _error = parsed.error;
        _result = null;
      });
      if (fromSubmit) _focus.requestFocus();
      return;
    }

    final mode = _mode;
    final table = widget.tables.ready(mode) ?? await widget.tables.get(mode);
    if (!mounted || token != _runToken) return;

    setState(() {
      _error = null;
      _result = table.optimize(parsed.value!);
    });
    if (fromSubmit) {
      _focus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealResult());
    }
  }

  /// Fait défiler juste ce qu'il faut pour montrer le résultat.
  void _revealResult() {
    final box = _resultKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients || !box.attached) return;
    final viewport = _scroll.position.viewportDimension;
    final top = box.localToGlobal(Offset.zero).dy - MediaQuery.paddingOf(context).top;
    if (top + 120 < viewport) return; // Le début du résultat est déjà visible.
    final target = (_scroll.offset + top - 16).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: _curve);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final form = _AmountCard(
      mode: _mode,
      controller: _controller,
      focusNode: _focus,
      error: _error,
      onChanged: _onChanged,
      onSubmit: () => _run(fromSubmit: true),
    );
    final result = _AnimatedResult(key: _resultKey, result: _result, mode: _mode);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: p.bg,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _focus.unfocus(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _twoColumnWidth;
                final controls = <Widget>[
                  const _Header(),
                  const SizedBox(height: 24),
                  _ModeSelector(mode: _mode, onChanged: _setMode),
                  const SizedBox(height: 16),
                  form,
                ];
                final secondary = <Widget>[
                  const SizedBox(height: 8),
                  _Tariffs(mode: _mode),
                  const SizedBox(height: 8),
                  const _Footer(),
                ];

                return SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 920 : 480),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [...controls, ...secondary],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 68),
                                    child: result,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [...controls, result, ...secondary],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- En-tête ---------- */

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(innerRadius),
          ),
          child: Icon(Icons.swap_horiz_rounded, color: p.surface, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MvolaSave',
                style: TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: p.text,
                ),
              ),
              Text(
                'Économisez sur vos frais MVola.',
                style: TextStyle(fontSize: 14, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ---------- Choix du service ---------- */

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final Mode mode;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(radius)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: _switch,
            curve: _curve,
            alignment: mode == Mode.transfer ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(innerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: p.shadow),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                // Chaque bouton occupe toute la hauteur : le fond pressé aussi.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeButton(
                    label: Mode.transfer.label,
                    icon: Icons.swap_horiz_rounded,
                    selected: mode == Mode.transfer,
                    onTap: () => onChanged(Mode.transfer),
                  ),
                  _ModeButton(
                    label: Mode.withdrawal.label,
                    icon: Icons.payments_outlined,
                    selected: mode == Mode.withdrawal,
                    onTap: () => onChanged(Mode.withdrawal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(innerRadius),
          child: TweenAnimationBuilder<Color?>(
            duration: _switch,
            tween: ColorTween(end: selected ? p.text : p.muted),
            builder: (context, color, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- Saisie ---------- */

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.mode,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onSubmit,
  });

  final Mode mode;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(innerRadius),
      borderSide: BorderSide(color: color, width: width),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: _fast,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
            child: Text(
              mode.question,
              key: ValueKey(mode),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: const [AmountInputFormatter()],
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            autocorrect: false,
            enableSuggestions: false,
            cursorWidth: 2,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: p.text,
              fontFeatures: tabular,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: p.bg,
              hintText: '1 000 000',
              hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.6)),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  'Ar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.muted),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(),
              enabledBorder: border(error == null ? p.border : p.danger),
              focusedBorder: border(error == null ? p.accent : p.danger, 2),
            ),
          ),
          const SizedBox(height: 8),
          Text('De 100 Ar à 20 000 000 Ar', style: TextStyle(fontSize: 13, color: p.muted)),
          AnimatedSize(
            duration: _fast,
            curve: _curve,
            alignment: Alignment.topLeft,
            child: error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(error!, style: TextStyle(fontSize: 14, color: p.danger)),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: p.text,
                foregroundColor: p.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(innerRadius)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('Optimiser'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chiffres uniquement, groupés par milliers, 8 chiffres au plus.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  static final RegExp _nonDigit = RegExp(r'\D');
  static final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final caret = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, raw.length)
        : raw.length;
    var digitsBeforeCaret = raw.substring(0, caret).replaceAll(_nonDigit, '').length;
    var digits = raw.replaceAll(_nonDigit, '');

    // Effacer un séparateur efface le chiffre qui le précède.
    if (raw.length < oldValue.text.length &&
        digits == oldValue.text.replaceAll(_nonDigit, '') &&
        digitsBeforeCaret > 0) {
      digits = digits.substring(0, digitsBeforeCaret - 1) + digits.substring(digitsBeforeCaret);
      digitsBeforeCaret--;
    }

    digits = digits.replaceFirst(_leadingZeros, '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final text = digits.isEmpty ? '' : formatNumber(int.parse(digits));

    var pos = 0;
    for (var seen = 0; pos < text.length && seen < digitsBeforeCaret; pos++) {
      if (text.codeUnitAt(pos) != 0xA0) seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

/* ---------- Résultat ---------- */

class _AnimatedResult extends StatelessWidget {
  const _AnimatedResult({super.key, required this.result, required this.mode});

  final OptimizationResult? result;
  final Mode mode;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return AnimatedSize(
      duration: _fast,
      curve: _curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _fast,
        switchInCurve: _curve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final child in previous) Positioned(left: 0, right: 0, top: 0, child: child),
            ?current,
          ],
        ),
        child: r == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ObjectKey(r),
                padding: const EdgeInsets.only(top: 16),
                child: _ResultCard(result: r, mode: mode),
              ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.mode});

  final OptimizationResult result;
  final Mode mode;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = result;
    final hasSavings = r.savings > 0;
    final count = r.operations.length;
    final total = r.operations.fold(0, (s, op) => s + op.amount);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatAr(r.amount),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: p.text,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: mode.normalLabel, value: formatAr(r.normalFee)),
          Divider(height: 1, color: p.border),
          _SummaryRow(label: 'Frais optimisés', value: formatAr(r.optimizedFee)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasSavings ? p.accentSoft : p.bg,
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: hasSavings ? p.accent : p.muted,
                fontFeatures: tabular,
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('Économie')),
                  Text(formatAr(r.savings)),
                ],
              ),
            ),
          ),
          if (!hasSavings) ...[
            const SizedBox(height: 10),
            Text(mode.alreadyOptimal, style: TextStyle(fontSize: 14, color: p.muted)),
          ],
          const SizedBox(height: 20),
          Text(
            'Répartition recommandée',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < count; i++)
            _OperationRow(label: '${mode.operation} ${i + 1}', operation: r.operations[i]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Total', style: TextStyle(fontSize: 16, color: p.text)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  count > 1 ? '$count opérations' : '1 opération',
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ),
              Text(
                formatAr(total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                  fontFeatures: tabular,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 15, color: p.muted)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.text,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.label, required this.operation});

  final String label;
  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: p.muted)),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatAr(operation.amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
                Text(
                  '→ ${formatAr(operation.fee)}',
                  style: TextStyle(fontSize: 15, color: p.muted, fontFeatures: tabular),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- Tarifs ---------- */

class _Tariffs extends StatefulWidget {
  const _Tariffs({required this.mode});

  final Mode mode;

  @override
  State<_Tariffs> createState() => _TariffsState();
}

class _TariffsState extends State<_Tariffs> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(foregroundColor: p.muted),
            icon: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: _fast,
              curve: _curve,
              child: const Icon(Icons.expand_more_rounded, size: 20),
            ),
            label: const Text('Voir les tarifs'),
          ),
        ),
        AnimatedSize(
          duration: _fast,
          curve: _curve,
          alignment: Alignment.topCenter,
          // La grille n'est construite que lorsqu'elle est affichée.
          child: _open ? _TariffTable(mode: widget.mode) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _TariffTable extends StatelessWidget {
  const _TariffTable({required this.mode});

  final Mode mode;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rowStyle = TextStyle(fontSize: 14, color: p.text, fontFeatures: tabular);
    final headStyle = TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w500);

    Widget row(String left, String right, TextStyle style, {bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: p.border)),
            ),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style)),
          Text(right, style: style),
        ],
      ),
    );

    final tiers = mode.tiers;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              mode.tariffsTitle,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row('Montant (Ar)', 'Frais', headStyle),
                for (var i = 0; i < tiers.length; i++)
                  row(
                    '${formatNumber(tiers[i].min)} – ${formatNumber(tiers[i].max)}',
                    formatAr(tiers[i].fee),
                    rowStyle,
                    last: i == tiers.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- Éléments communs ---------- */

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: padding,
      clipBehavior: padding == EdgeInsets.zero ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Text(
      'Application indépendante, non affiliée à MVola.\n'
      'Tarifs indicatifs. Calcul effectué hors ligne.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
    );
  }
}
