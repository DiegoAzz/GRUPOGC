import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/main.dart';
import 'package:grupo_cg/document.dart';

void main() {
  testWidgets('El acceso exige credenciales', (tester) async {
    await tester.pumpWidget(const CobrosApp());
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Completa el campo Correo.'), findsOneWidget);
    expect(find.text('Completa el campo Contraseña.'), findsOneWidget);
  });
  test('Importes en letras', () {
    expect(words(1430000), 'un millón cuatrocientos treinta mil');
    expect(words(100), 'cien');
    expect(words(105), 'ciento cinco');
    expect(words(25000), 'veinticinco mil');
  });
  test('Genera un PDF con firma y detalle de varias páginas', () async {
    final bytes = await buildDocument({
      'number': 'CG-000001',
      'date': '2026-09-26',
      'from': '2026-09-01',
      'to': '2026-09-26',
      'concept': 'Transporte',
      'total': 250000000,
      'client': {'name': 'Cliente de prueba', 'document': '123'},
      'issuer': {
        'name': 'Emisor',
        'document': '456',
        'phone': '3000000000',
        'email': 'test@example.com',
        'address': 'Dirección',
        'city': 'Cartagena'
      },
      'signature': {
        'name': 'Firmante',
        'document': '456',
        'image': base64Encode(img.encodePng(img.Image(width: 20, height: 10)))
      },
      'rows': List.generate(
          100,
          (i) => {
                'date': '2026-09-10',
                'vehicle': 'ABC123',
                'driver': 'Conductor',
                'sheet': '$i',
                'amount': 2500000
              }),
    });
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
