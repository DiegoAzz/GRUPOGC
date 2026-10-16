import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/api.dart';
import 'package:grupo_cg/document.dart';
import 'package:grupo_cg/loans_page.dart';
import 'package:grupo_cg/main.dart';

class LoanApi extends Api {
  final payments = <Map<String, dynamic>>[];
  int writes = 0;
  @override
  Future<dynamic> call(String action, [Map<String, dynamic>? data]) async {
    if (action == 'state') {
      return {
        'loans': [
          {
            'id': 1,
            'name': 'Ana',
            'date': '2026-01-01',
            'amount': 10000,
            'payments': payments.map((p) => {...p}).toList()
          }
        ]
      };
    }
    if (action == 'add_loan_payment') {
      writes++;
      payments.add({
        'date': data!['date'],
        'amount': (double.parse(data['value'] as String) * 100).round()
      });
      return true;
    }
    throw StateError(action);
  }
}

void main() {
  testWidgets('Contabilidad despliega préstamos y abonos como submenús',
      (tester) async {
    final api = LoanApi()..token = 'test';
    await tester.pumpWidget(MaterialApp(home: Home(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Contabilidad'));
    await tester.tap(find.text('Contabilidad'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresos y gastos'), findsOneWidget);
    expect(find.text('Préstamos'), findsOneWidget);
    await tester.ensureVisible(find.text('Abonos de préstamos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abonos de préstamos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('select_loan_payment')), findsOneWidget);
    expect(find.text('Nuevo préstamo'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('select_loan_payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('loan_id')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ana ·').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Registrar abono · Ana'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('value')), '40');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(find.text('Saldo pendiente: ${money(6000)}'), findsOneWidget);
    expect(find.text('Abono: ${money(4000)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Abonos actualizan el saldo e impiden superar lo pendiente',
      (tester) async {
    final api = LoanApi();
    await tester.pumpWidget(MaterialApp(home: LoansPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('value')), '25');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(find.text('Saldo pendiente: ${money(7500)}'), findsOneWidget);
    expect(find.textContaining('Abono:'), findsOneWidget);
    expect(find.textContaining('Saldo restante: ${money(7500)}'),
        findsNWidgets(2));
    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('value')), '30');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.writes, 2);
    expect(find.text('Saldo pendiente: ${money(4500)}'), findsOneWidget);
    expect(
        find.textContaining('Saldo restante: ${money(7500)}'), findsOneWidget);
    expect(find.textContaining('Saldo restante: ${money(4500)}'),
        findsNWidgets(2));
    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('value')), '76');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.writes, 2);
    expect(
        find.text(
            'El abono supera el saldo o su fecha es anterior al préstamo.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
