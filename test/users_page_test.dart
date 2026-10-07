import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/api.dart';
import 'package:grupo_cg/users_page.dart';

class UsersApi extends Api {
  final users = <Map<String, dynamic>>[
    {'id': 1, 'email': 'admin@example.com'}
  ];
  @override
  Future<dynamic> call(String action, [Map<String, dynamic>? data]) async {
    if (action == 'users_list') return users.map((u) => {...u}).toList();
    if (action == 'create_user') {
      expect(
          data, {'email': 'nuevo@example.com', 'password': 'clave-prueba-123'});
      users.add({'id': 2, 'email': data!['email']});
      return true;
    }
    if (action == 'delete_user') {
      users.removeWhere((u) => u['id'] == data!['id']);
      return true;
    }
    throw StateError(action);
  }
}

void main() {
  testWidgets('Crear usuario desde el módulo y eliminar con confirmación',
      (tester) async {
    final api = UsersApi();
    await tester.pumpWidget(MaterialApp(home: UsersPage(api: api, adminId: 1)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Eliminar usuario'), findsNothing);
    await tester.tap(find.text('Crear usuario'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('email')), 'nuevo@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('password')), 'clave-prueba-123');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('nuevo@example.com'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar usuario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.users.length, 2);
    await tester.tap(find.byTooltip('Eliminar usuario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(api.users.length, 1);
    expect(tester.takeException(), isNull);
  });
}
