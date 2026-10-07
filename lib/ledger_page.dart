import 'package:flutter/material.dart';
import 'api.dart';
import 'document.dart';
import 'record_form.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.api});
  final Api api;
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  List<Map<String, dynamic>> entries = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    run(load);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
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
      setState(() => entries = (state['ledger'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
    }
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final initial = <String, dynamic>{...?item};
    initial['date'] ??= DateTime.now().toIso8601String().substring(0, 10);
    initial['kind'] ??= 'expense';
    if (item != null) {
      initial['value'] = ((item['amount'] as num) / 100).toStringAsFixed(2);
    }
    final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => RecordFormDialog(
              title: item == null ? 'Nuevo movimiento' : 'Editar movimiento',
              fields: const {
                'date': 'Fecha',
                'kind': 'Tipo',
                'detail': 'Detalle',
                'value': 'Valor en pesos'
              },
              initial: initial,
              choices: const {
                'kind': [
                  DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                  DropdownMenuItem(value: 'expense', child: Text('Gasto'))
                ]
              },
            ));
    if (values == null || !mounted) return;
    await run(() async {
      await widget.api
          .call('save_ledger', {...values, if (item != null) 'id': item['id']});
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movimiento guardado.')));
      }
    });
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('¿Eliminar movimiento?'),
                content: Text(
                    'Se eliminará «${item['detail']}» y el saldo se recalculará.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'))
                ]));
    if (confirmed != true || !mounted) return;
    await run(() async {
      await widget.api.call('delete', {'entity': 'ledger', 'id': item['id']});
      await load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final income = entries
        .where((e) => e['kind'] == 'income')
        .fold<int>(0, (sum, e) => sum + (e['amount'] as num).toInt());
    final expense = entries
        .where((e) => e['kind'] == 'expense')
        .fold<int>(0, (sum, e) => sum + (e['amount'] as num).toInt());
    return Scaffold(
      appBar: AppBar(title: const Text('Contabilidad'), actions: [
        IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : () => run(load),
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (busy) const LinearProgressIndicator(),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo: ${money(income - expense)}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Ingresos: ${money(income)}'),
                      Text('Gastos: ${money(expense)}'),
                    ]))),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Center(child: Text('Aún no hay ingresos ni gastos.')),
        for (final entry in entries)
          Card(
              child: ListTile(
            leading: Icon(
                entry['kind'] == 'income'
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: entry['kind'] == 'income' ? Colors.green : Colors.red),
            title: Text(entry['detail'] as String),
            subtitle: Text(
                '${entry['date']} · ${entry['kind'] == 'income' ? 'Ingreso' : 'Gasto'}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  '${entry['kind'] == 'income' ? '+' : '−'}${money(entry['amount'] as num)}'),
              IconButton(
                  tooltip: 'Eliminar movimiento',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy ? null : () => remove(entry)),
            ]),
            onTap: busy ? null : () => edit(entry),
          )),
        const SizedBox(height: 80),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo movimiento')),
    );
  }
}
