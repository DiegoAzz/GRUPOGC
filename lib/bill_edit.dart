import 'package:flutter/material.dart';

import 'record_form.dart';
import 'document.dart';

class BillEditDialog extends StatefulWidget {
  const BillEditDialog({super.key, required this.contextData});
  final Map<String, dynamic> contextData;
  @override
  State<BillEditDialog> createState() => _BillEditDialogState();
}

class _BillEditDialogState extends State<BillEditDialog> {
  late final List<Map<String, dynamic>> rows =
      (widget.contextData['rows'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  late String date = widget.contextData['bill']['date'] as String;
  final List<Map<String, dynamic>> newRows = [];
  final List<Map<String, dynamic>> deletedRows = [];

  Future<void> addRow() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => RecordFormDialog(
        title: 'Añadir planilla',
        fields: const {
          'date': 'Fecha',
          'sheet': 'Planilla',
          'vehicle_id': 'Vehículo / placa',
          'driver_id': 'Conductor',
          'value': 'Valor en pesos',
        },
        initial: {'date': date},
        choices: {
          for (final entry in {
            'vehicle_id': 'vehicles',
            'driver_id': 'drivers',
          }.entries)
            entry.key: (widget.contextData[entry.value] as List? ?? [])
                .map(
                  (r) => DropdownMenuItem<String>(
                    value: '${r['id']}',
                    child: Text(r['name'] as String),
                  ),
                )
                .toList(),
        },
      ),
    );
    if (values != null && mounted) {
      setState(() => newRows.add(Map<String, dynamic>.from(values)));
    }
  }

  Future<void> editRow(Map<String, dynamic> row) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => RecordFormDialog(
        title: 'Editar planilla ${row['sheet']}',
        fields: const {
          'date': 'Fecha',
          'sheet': 'Planilla',
          'value': 'Valor en pesos',
        },
        initial: row,
      ),
    );
    if (values != null && mounted) setState(() => row.addAll(values));
  }

  @override
  Widget build(BuildContext context) {
    final total = [...rows, ...newRows].fold<num>(
      0,
      (sum, r) =>
          sum +
          (double.parse((r['value'] as String).replaceAll(',', '.')) * 100)
              .round(),
    );
    return AlertDialog(
      title: Text('Editar cuenta ${widget.contextData['bill']['number']}'),
      content: SizedBox(
        width: 600,
        height: 450,
        child: ListView(
          children: [
            const Text(
              'Se actualizarán las planillas originales y esta cuenta. Su consecutivo se conserva. Los PDF descargados deben descargarse de nuevo.',
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: addRow,
              icon: const Icon(Icons.add),
              label: const Text('Añadir planilla'),
            ),
            const Text(
                'Las planillas añadidas se registran para el cliente de esta cuenta al guardar.'),
            ListTile(
              title: const Text('Fecha del documento'),
              subtitle: Text(date),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(date),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(
                    () => date = picked.toIso8601String().substring(0, 10),
                  );
                }
              },
            ),
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text('Planilla ${row['sheet']}'),
                  subtitle: Text(
                    '${row['date']} · ${money((double.parse((row['value'] as String).replaceAll(',', '.')) * 100).round())}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar planilla',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => editRow(row),
                      ),
                      IconButton(
                        tooltip: 'Eliminar planilla',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          rows.remove(row);
                          deletedRows.add(row);
                        }),
                      ),
                    ],
                  ),
                  onTap: () => editRow(row),
                ),
              ),
            for (final row in newRows)
              Card(
                child: ListTile(
                  title: Text('Planilla ${row['sheet']} (nueva)'),
                  subtitle: Text(
                    '${row['date']} · ${money((double.parse((row['value'] as String).replaceAll(',', '.')) * 100).round())}',
                  ),
                  onTap: () => editRow(row),
                  trailing: IconButton(
                    tooltip: 'Quitar planilla añadida',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => newRows.remove(row)),
                  ),
                ),
              ),
            if (deletedRows.isNotEmpty) ...[
              const Text(
                'Al guardar se eliminarán estas planillas de la cuenta y de los cobros originales.',
              ),
              for (final row in deletedRows)
                ListTile(
                  title: Text('Planilla ${row['sheet']} por eliminar'),
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      deletedRows.remove(row);
                      rows.add(row);
                    }),
                    child: const Text('Deshacer'),
                  ),
                ),
            ],
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Total actualizado: ${money(total)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: rows.isEmpty && newRows.isEmpty
              ? null
              : () => Navigator.pop(context, <String, dynamic>{
                    'id': widget.contextData['bill']['id'],
                    'revision': widget.contextData['revision'],
                    'date': date,
                    'rows': rows,
                    'new_rows': newRows,
                    'deleted_rows': deletedRows,
                  }),
          child: const Text('Guardar cuenta y planillas'),
        ),
      ],
    );
  }
}
