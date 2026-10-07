import 'package:flutter/material.dart';

const standardBillColumns = <String, String>{
  'date': 'Fecha',
  'vehicle': 'Vehículo',
  'driver': 'Conductor',
  'sheet': 'Planilla',
  'amount': 'Valor',
};

List<Map<String, dynamic>> billColumns(Map<String, dynamic> bill) =>
    bill['columns'] == null
        ? standardBillColumns.entries
            .map((e) => <String, dynamic>{'key': e.key, 'label': e.value})
            .toList()
        : (bill['columns'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

class BillColumnsDialog extends StatefulWidget {
  const BillColumnsDialog({super.key, required this.bill});
  final Map<String, dynamic> bill;

  @override
  State<BillColumnsDialog> createState() => _BillColumnsDialogState();
}

class _BillColumnsDialogState extends State<BillColumnsDialog> {
  late final List<Map<String, dynamic>> columns = billColumns(widget.bill);
  late final List<Map<String, dynamic>> rows = (widget.bill['rows'] as List)
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
  late final Map<String, Map<String, String>> values = {
    for (final row in rows)
      '${row['id']}': {
        for (final entry in (row['custom_values'] as Map? ?? {}).entries)
          '${entry.key}': '${entry.value}'
      }
  };
  final name = TextEditingController();
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void addColumn() {
    final label = name.text.trim();
    if (label.isEmpty ||
        label.length > 60 ||
        columns.length >= 10 ||
        columns.any((c) =>
            (c['label'] as String).toLowerCase() == label.toLowerCase())) {
      setState(() => error =
          'Escribe un nombre único de hasta 60 caracteres. Máximo 10 columnas.');
      return;
    }
    setState(() {
      columns.add({
        'key': 'custom_${DateTime.now().microsecondsSinceEpoch}',
        'label': label
      });
      name.clear();
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Columnas de la cuenta'),
        content: SizedBox(
            width: 600,
            height: 480,
            child: ListView(children: [
              const Text(
                  'Selecciona las columnas del detalle. El total de la cuenta se conserva.'),
              for (final entry in standardBillColumns.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: columns.any((c) => c['key'] == entry.key),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      if (columns.length >= 10) {
                        error = 'Máximo 10 columnas.';
                        return;
                      }
                      columns.add({'key': entry.key, 'label': entry.value});
                    } else {
                      columns.removeWhere((c) => c['key'] == entry.key);
                    }
                    error = null;
                  }),
                ),
              const Divider(),
              TextField(
                  controller: name,
                  maxLength: 60,
                  decoration: const InputDecoration(
                      labelText: 'Nuevo campo',
                      hintText: 'Ejemplo: Ruta u Observaciones'),
                  onSubmitted: (_) => addColumn()),
              TextButton.icon(
                  onPressed: addColumn,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir campo')),
              for (final column in columns
                  .where((c) => !standardBillColumns.containsKey(c['key'])))
                ExpansionTile(
                    key: ValueKey(column['key']),
                    title: Text(column['label'] as String),
                    trailing: IconButton(
                        tooltip: 'Quitar campo',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            setState(() => columns.remove(column))),
                    children: [
                      const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                              'Completa el valor para cada fila; puedes dejarlo vacío.')),
                      for (final row in rows)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextFormField(
                              key: ValueKey('${column['key']}_${row['id']}'),
                              initialValue:
                                  values['${row['id']}']?[column['key']] ?? '',
                              maxLength: 200,
                              decoration: InputDecoration(
                                  labelText:
                                      'Planilla ${row['sheet']} · ${row['date']}'),
                              onChanged: (value) => values['${row['id']}']![
                                  column['key'] as String] = value,
                            )),
                    ]),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (columns.isEmpty) {
                  setState(() => error = 'Selecciona al menos una columna.');
                  return;
                }
                Navigator.pop(context, <String, dynamic>{
                  'columns': columns,
                  'custom_values': values
                });
              },
              child: const Text('Aplicar')),
        ],
      );
}
