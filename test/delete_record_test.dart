import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/api.dart';
import 'package:grupo_cg/main.dart';

class FakeApi extends Api {
  FakeApi({this.entity = 'clients'});
  final String entity;
  bool rejectDelete = false;
  int deletes = 0;
  final records = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'Cliente prueba',
      'document': '123',
      'sheet': '001',
      'amount': 10000,
      'date': '2026-09-27',
      'image':
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aCWQAAAAASUVORK5CYII='
    }
  ];

  @override
  Future<dynamic> call(String action, [Map<String, dynamic>? data]) async {
    if (action == 'login') return {'token': 'test'};
    if (action == 'delete') {
      deletes++;
      expect(data, {'entity': entity, 'id': 1});
      if (rejectDelete) throw Exception('Hay cobros asociados.');
      records.clear();
      return true;
    }
    return {
      'clients': [],
      'charges': [],
      'signatures': [],
      'bills': [],
      'issuer': {},
      'vehicles': [],
      'drivers': [],
      entity: entity == 'issuer'
          ? (records.isEmpty ? <String, dynamic>{} : {...records.single})
          : records.map((r) => {...r}).toList(),
    };
  }
}

Future<void> openClients(WidgetTester tester, FakeApi api,
    {String page = 'Clientes'}) async {
  await tester.pumpWidget(MaterialApp(home: Home(api: api)));
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('email')), 'test@example.com');
  await tester.enterText(
      find.byKey(const ValueKey('password')), 'test-password');
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(page).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'clients': 'Clientes',
    'drivers': 'Conductores',
    'vehicles': 'Vehículos',
    'charges': 'Cobros',
    'signatures': 'Firmas',
    'issuer': 'Datos del emisor',
  }.entries) {
    testWidgets('Eliminar desde formulario móvil: ${entry.value}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeApi(entity: entry.key);
      await openClients(tester, api, page: entry.value);
      await tester.tap(entry.key == 'issuer'
          ? find.text('Editar datos del emisor')
          : entry.key == 'charges'
              ? find.textContaining('Planilla 001')
              : find.text('Cliente prueba'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(api.deletes, 0);
      expect(find.text('¿Eliminar registro?'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(api.deletes, 1);
      expect(find.text('Registro eliminado correctamente.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Cancelar conserva el registro; confirmar lo elimina',
      (tester) async {
    final api = FakeApi();
    await openClients(tester, api);
    await tester.tap(find.byTooltip('Eliminar registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.deletes, 0);
    expect(find.text('Cliente prueba'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(api.deletes, 1);
    expect(find.text('Cliente prueba'), findsNothing);
    expect(find.text('Registro eliminado correctamente.'), findsOneWidget);
  });

  testWidgets(
      'Un rechazo del servidor conserva el registro y muestra el motivo',
      (tester) async {
    final api = FakeApi()..rejectDelete = true;
    await openClients(tester, api);
    await tester.tap(find.byTooltip('Eliminar registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente prueba'), findsOneWidget);
    expect(find.text('Hay cobros asociados.'), findsOneWidget);
  });
}
