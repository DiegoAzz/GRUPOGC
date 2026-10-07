import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:grupo_cg/api.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/main.dart';
import 'package:grupo_cg/document.dart';

void main() {
  testWidgets('El acceso exige credenciales', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Home(api: Api())));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('grupocg@gmail.com'), findsOneWidget);
    expect(find.text('Completa el campo Contraseña.'), findsOneWidget);
  });
  test('Importes en letras', () {
    expect(words(1430000), 'un millón cuatrocientos treinta mil');
    expect(words(100), 'cien');
    expect(words(105), 'ciento cinco');
    expect(words(25000), 'veinticinco mil');
  });
  for (final custom in [false, true]) {
    test('Genera PDF de varias páginas; columnas personalizadas: $custom',
        () async {
      final bytes = await buildDocument({
        'number': 'CG-000001',
        'date': '2026-09-26',
        'from': '2026-09-01',
        'to': '2026-09-26',
        'concept': 'Transporte',
        'total': 250000000,
        if (custom) ...{
          'template': 'equivalent_v1',
          'document_city': 'CARTAGENA',
          'recipient': {
            'name': 'COMERCIALIZADORA MULTIDROGAS DE COLOMBIA S.A.S.',
            'document': '823.000.097'
          },
          'legal_legend': 'ART.3ro. decreto 522 de marzo de 2003.',
        },
        if (custom)
          'columns': [
            {'key': 'date', 'label': 'Fecha'},
            {'key': 'sheet', 'label': 'Planilla'},
            {'key': 'amount', 'label': 'Valor'},
            {'key': 'custom_route', 'label': 'Ruta'},
            {'key': 'custom_note', 'label': 'Observaciones'},
            {'key': 'driver', 'label': 'Conductor'},
          ],
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
                  'amount': 2500000,
                  'custom_values': {
                    'custom_route': 'Cartagena - Barranquilla',
                    'custom_note': 'Entrega de prueba'
                  }
                }),
      });
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
  }
}
