import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/api.dart';
import 'package:grupo_cg/ledger_page.dart';
import 'package:grupo_cg/planilla_photos_page.dart';

class ModulesApi extends Api {
  int photoFetches = 0;
  final entries = <Map<String, dynamic>>[
    {
      'id': 1,
      'date': '2026-10-06',
      'kind': 'income',
      'detail': 'Venta',
      'amount': 10000
    },
    {
      'id': 2,
      'date': '2026-10-06',
      'kind': 'expense',
      'detail': 'Combustible',
      'amount': 2550
    },
  ];
  final photos = <Map<String, dynamic>>[
    {'id': 3, 'sheet': 'PLAN-001', 'created_at': '2026-10-06T10:00:00'}
  ];
  @override
  Future<dynamic> call(String action, [Map<String, dynamic>? data]) async {
    if (action == 'state') {
      return {
        'ledger': entries.map((e) => {...e}).toList(),
        'planilla_photos': photos.map((p) => {...p}).toList()
      };
    }
    if (action == 'photo_get') {
      photoFetches++;
      return {
        'id': 3,
        'sheet': 'PLAN-001',
        'image':
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
      };
    }
    if (action == 'save_ledger') {
      entries.add({
        'id': 4,
        'date': data!['date'],
        'kind': data['kind'],
        'detail': data['detail'],
        'amount': 2000
      });
      return true;
    }
    if (action == 'delete') {
      entries.removeWhere((e) => e['id'] == data!['id']);
      return true;
    }
    throw StateError(action);
  }
}

void main() {
  testWidgets(
      'Contabilidad muestra saldo tras descontar gastos y guarda detalle',
      (tester) async {
    final api = ModulesApi();
    await tester.pumpWidget(MaterialApp(home: LedgerPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('74,50'), findsOneWidget);
    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('detail')), 'Peaje');
    await tester.enterText(find.byKey(const ValueKey('value')), '20');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Peaje'), findsOneWidget);
    expect(find.textContaining('54,50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Las fotos se consultan al abrir la planilla, no al listar',
      (tester) async {
    final api = ModulesApi();
    await tester.pumpWidget(MaterialApp(home: PlanillaPhotosPage(api: api)));
    await tester.pumpAndSettle();
    expect(api.photoFetches, 0);
    await tester.tap(find.text('Planilla PLAN-001'));
    await tester.pumpAndSettle();
    expect(api.photoFetches, 0);
    await tester.tap(find.text('Foto 1'));
    await tester.pumpAndSettle();
    expect(api.photoFetches, 1);
    expect(find.text('Planilla PLAN-001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Agrupa fotos y permite añadir más a la misma planilla',
      (tester) async {
    final api = ModulesApi();
    api.photos.add(
        {'id': 4, 'sheet': 'PLAN-001', 'created_at': '2026-10-07T10:00:00'});
    await tester.pumpWidget(MaterialApp(home: PlanillaPhotosPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Planilla PLAN-001'), findsOneWidget);
    expect(find.text('2 fotos'), findsOneWidget);
    await tester.tap(find.text('Planilla PLAN-001'));
    await tester.pumpAndSettle();
    expect(find.text('Foto 1'), findsOneWidget);
    expect(find.text('Foto 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Añadir fotos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'PLAN-001'), findsOneWidget);
    expect(find.text('0 fotos seleccionadas'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el número de planilla y selecciona una foto.'),
        findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.photos.length, 2);
    expect(api.photoFetches, 0);
    expect(tester.takeException(), isNull);
  });
}
