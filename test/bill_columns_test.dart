import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/bill_columns.dart';

void main() {
  testWidgets('Selecciona fecha, planilla y valor y guarda un campo por fila',
      (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => const BillColumnsDialog(bill: {
                                'rows': [
                                  {
                                    'id': 12,
                                    'sheet': '001',
                                    'date': '2026-09-27'
                                  }
                                ]
                              }));
                    },
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehículo'));
    await tester.tap(find.text('Conductor'));
    await tester.enterText(find.byType(TextField).last, 'Ruta');
    await tester.scrollUntilVisible(find.text('Añadir campo'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Añadir campo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ruta'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextFormField), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byType(TextFormField), 'Cartagena - Barranquilla');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    final columns = result!['columns'] as List;
    expect(
        columns.map((c) => c['label']), ['Fecha', 'Planilla', 'Valor', 'Ruta']);
    expect(result!['custom_values']['12'][columns.last['key']],
        'Cartagena - Barranquilla');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Una cuenta guardada recupera columnas y valores personalizados',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: BillColumnsDialog(bill: {
      'columns': [
        {'key': 'sheet', 'label': 'Planilla'},
        {'key': 'custom_route', 'label': 'Ruta'}
      ],
      'rows': [
        {
          'id': 12,
          'sheet': '001',
          'date': '2026-09-27',
          'custom_values': {'custom_route': 'Destino guardado'}
        }
      ]
    }))));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'Fecha'))
            .value,
        false);
    await tester.scrollUntilVisible(find.text('Ruta'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Destino guardado'), findsOneWidget);
  });
}
