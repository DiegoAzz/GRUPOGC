import 'package:flutter/material.dart';
import 'api.dart';
import 'document.dart';
import 'record_form.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key, required this.api, this.paymentsMode = false});
  final Api api;
  final bool paymentsMode;

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  List<Map<String, dynamic>> loans = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    run(load);
  }

  int paid(Map<String, dynamic> loan) => (loan['payments'] as List)
      .fold<int>(0, (sum, p) => sum + (p['amount'] as num).toInt());
  int balance(Map<String, dynamic> loan) =>
      (loan['amount'] as num).toInt() - paid(loan);

  List<Widget> paymentHistory(Map<String, dynamic> loan) {
    var remaining = (loan['amount'] as num).toInt();
    return [
      for (final payment in loan['payments'] as List)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.payments_outlined),
          title: Text('Abono: ${money(payment['amount'] as num)}'),
          subtitle: Text(
              'Fecha: ${payment['date']}\nSaldo restante: ${money(remaining -= (payment['amount'] as num).toInt())}'),
        ),
    ];
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    final state = await widget.api.call('state') as Map<String, dynamic>;
    if (mounted) {
      setState(() => loans = ((state['loans'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
    }
  }

  Future<void> selectLoanForPayment() async {
    final pending = loans.where((loan) => balance(loan) > 0).toList();
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => RecordFormDialog(
        title: 'Seleccionar préstamo para abonar',
        fields: const {'loan_id': 'Préstamo y saldo pendiente'},
        choices: {
          'loan_id': [
            for (final loan in pending)
              DropdownMenuItem(
                value: '${loan['id']}',
                child: Text(
                    '${loan['name']} · ${loan['date']} · Saldo: ${money(balance(loan))}'),
              ),
          ],
        },
      ),
    );
    if (selected == null || !mounted) return;
    await save(
        pending.firstWhere((loan) => '${loan['id']}' == selected['loan_id']));
  }

  Future<void> save([Map<String, dynamic>? loan]) async {
    final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => RecordFormDialog(
              title: loan == null
                  ? 'Nuevo préstamo'
                  : 'Registrar abono · ${loan['name']} · Saldo: ${money(balance(loan))}',
              fields: {
                if (loan == null) 'name': 'Nombre',
                'date': 'Fecha',
                'value': loan == null
                    ? 'Valor del préstamo en pesos'
                    : 'Abono en pesos',
              },
              initial: {
                'date': DateTime.now().toIso8601String().substring(0, 10)
              },
            ));
    if (values == null || !mounted) return;
    await run(() async {
      final amount =
          (num.parse(values['value']!.replaceAll(',', '.')) * 100).round();
      if (amount <= 0) throw Exception('El valor debe ser mayor que cero.');
      if (loan != null &&
          (amount > balance(loan) ||
              values['date']!.compareTo(loan['date'] as String) < 0)) {
        throw Exception(
            'El abono supera el saldo o su fecha es anterior al préstamo.');
      }
      await widget.api.call(loan == null ? 'save_loan' : 'add_loan_payment', {
        ...values,
        if (loan != null) 'id': loan['id'],
      });
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(loan == null ? 'Préstamo guardado.' : 'Abono guardado.')));
      }
    });
  }

  Future<void> remove(Map<String, dynamic> loan) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('¿Eliminar préstamo?'),
              content: Text(
                  'Se eliminará el préstamo de ${loan['name']} y todos sus abonos.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    await run(() async {
      await widget.api.call('delete', {'entity': 'loans', 'id': loan['id']});
      await load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = loans.fold<int>(0, (sum, loan) => sum + balance(loan));
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.paymentsMode ? 'Abonos de préstamos' : 'Préstamos'),
          actions: [
            IconButton(
                tooltip: 'Actualizar',
                onPressed: busy ? null : () => run(load),
                icon: const Icon(Icons.refresh)),
          ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (busy) const LinearProgressIndicator(),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Saldo pendiente: ${money(total)}',
                    style: Theme.of(context).textTheme.headlineSmall))),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
                'Los préstamos y sus abonos se controlan por separado de los ingresos y gastos.')),
        if (widget.paymentsMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              key: const ValueKey('select_loan_payment'),
              onPressed: busy || !loans.any((loan) => balance(loan) > 0)
                  ? null
                  : selectLoanForPayment,
              icon: const Icon(Icons.add_card),
              label: const Text('Seleccionar préstamo y registrar abono'),
            ),
          ),
        if (loans.isEmpty && !busy)
          const Center(child: Text('Aún no hay préstamos.')),
        for (final loan in loans)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan['name'] as String,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('Fecha: ${loan['date']}'),
                  const SizedBox(height: 8),
                  Text('Préstamo: ${money(loan['amount'] as num)}'),
                  Text('Total abonado: ${money(paid(loan))}'),
                  Text('Saldo restante: ${money(balance(loan))}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed:
                          busy || balance(loan) <= 0 ? null : () => save(loan),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(balance(loan) <= 0
                          ? 'Préstamo pagado'
                          : 'Registrar abono'),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : () => remove(loan),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar préstamo'),
                    ),
                  ]),
                  const Divider(height: 24),
                  Text('Historial de abonos',
                      style: Theme.of(context).textTheme.titleSmall),
                  if ((loan['payments'] as List).isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Sin abonos registrados.'),
                    ),
                  ...paymentHistory(loan),
                ],
              ),
            ),
          ),
        const SizedBox(height: 80),
      ]),
      floatingActionButton: widget.paymentsMode
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : () => save(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo préstamo')),
    );
  }
}
