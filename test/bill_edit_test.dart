import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/bill_edit.dart';

void main() {
  testWidgets('Eliminar una repetida permite deshacer y guarda solo su ID',
      (tester) async {
    Map<String, dynamic>? result;
    final data = <String, dynamic>{
      'bill': {'id': 485, 'number': 'CC-485', 'date': '2026-10-01'},
      'revision': 'bill-version',
      'rows': [
        for (final id in [1, 2])
          {
            'id': id,
            'date': '2026-10-01',
            'sheet': '518144',
            'value': '105040.00',
            'revision': 'version-$id',
          },
      ],
    };
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => BillEditDialog(contextData: data),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              )),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar planilla').first);
    await tester.pumpAndSettle();
    expect(find.text('Planilla 518144'), findsOneWidget);
    expect(data['rows'], hasLength(2));
    expect(result, isNull);
    await tester.ensureVisible(find.text('Deshacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('Planilla 518144'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('Eliminar planilla').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar planilla').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cuenta y planillas'));
    await tester.pumpAndSettle();
    expect(result!['rows'].single['id'], 1);
    expect(result!['deleted_rows'].single['id'], 2);
    expect(result!['deleted_rows'].single['revision'], 'version-2');
    expect(data['rows'], hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Añadir planilla queda pendiente y se puede quitar antes de guardar',
    (tester) async {
      Map<String, dynamic>? result;
      final contextData = <String, dynamic>{
        'bill': {'id': 476, 'number': 'CC-476', 'date': '2026-09-28'},
        'revision': 'bill-version',
        'rows': <Map<String, dynamic>>[],
        'vehicles': [
          {'id': 2, 'name': 'ABC123'},
        ],
        'drivers': [
          {'id': 3, 'name': 'Conductor'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => BillEditDialog(contextData: contextData),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      Future<void> addSheet(String sheet) async {
        await tester.tap(find.text('Añadir planilla').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('sheet')), sheet);
        await tester.ensureVisible(find.byKey(const ValueKey('vehicle_id')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('vehicle_id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ABC123').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('driver_id')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('driver_id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Conductor').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('value')));
        await tester.enterText(find.byKey(const ValueKey('value')), '200,50');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
      }

      await addSheet('002');
      expect(result, isNull);
      expect(contextData['rows'], isEmpty);
      expect(find.text('Planilla 002 (nueva)'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Quitar planilla añadida'));
      await tester.tap(find.byTooltip('Quitar planilla añadida'));
      await tester.pumpAndSettle();
      expect(find.text('Planilla 002 (nueva)'), findsNothing);
      await tester.ensureVisible(find.text('Añadir planilla'));
      await addSheet('003');
      await tester.tap(find.text('Guardar cuenta y planillas'));
      await tester.pumpAndSettle();
      expect(result!['new_rows'], [
        {
          'date': '2026-09-28',
          'sheet': '003',
          'vehicle_id': '2',
          'driver_id': '3',
          'value': '200,50',
        },
      ]);
      expect(result!['id'], 476);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Editar planilla queda pendiente hasta guardar la cuenta', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    final contextData = <String, dynamic>{
      'bill': {'id': 476, 'number': 'CC-476', 'date': '2026-09-28'},
      'revision': 'bill-version',
      'rows': [
        {
          'id': 1,
          'date': '2026-09-27',
          'sheet': '001',
          'value': '100.00',
          'revision': 'source-version',
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => BillEditDialog(contextData: contextData),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar planilla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sheet')), '002');
    await tester.enterText(find.byKey(const ValueKey('value')), '200,50');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(contextData['rows'][0]['value'], '100.00');
    expect(find.text('Planilla 002'), findsOneWidget);
    await tester.tap(find.text('Guardar cuenta y planillas'));
    await tester.pumpAndSettle();
    expect(result!['id'], 476);
    expect(result!['rows'][0]['value'], '200,50');
    expect(result!['rows'][0]['revision'], 'source-version');
    expect(tester.takeException(), isNull);
  });
}
