import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/bill_edit.dart';

void main() {
  testWidgets('Editar planilla queda pendiente hasta guardar la cuenta',
      (tester) async {
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
          'revision': 'source-version'
        }
      ],
    };
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) =>
                              BillEditDialog(contextData: contextData));
                    },
                    child: const Text('Abrir'))))));
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
