import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_cg/record_form.dart';

void main() {
  testWidgets('Guarda un valor cero sin convertirlo en un campo vacío',
      (tester) async {
    Map<String, String>? saved;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (_) => const RecordFormDialog(
                        title: 'Cobro',
                        fields: {'value': 'Valor en pesos'},
                      ),
                    );
                  },
                  child: const Text('Nuevo'),
                ),
              )),
    ));
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('value')), '0');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved, {'value': '0'});
    expect(find.byType(RecordFormDialog), findsNothing);
  });

  test(
      'El valor rechaza letras, símbolos y pegados inválidos sin alterar el importe',
      () {
    String? error;
    final formatter = AmountInputFormatter((v) => error = v);
    const old = TextEditingValue(text: '25000');
    for (final input in [
      '25000abc',
      r'$25000',
      '-25000',
      '25 000',
      '25.000,50',
      '1e5',
      '1,234',
      '1234567890'
    ]) {
      expect(
          formatter.formatEditUpdate(old, TextEditingValue(text: input)), old);
      expect(error, isNotNull);
    }
    for (final input in [
      '25000',
      '25000,50',
      '25000.50',
      '0,01',
      '999999999.99',
      ''
    ]) {
      expect(
          formatter.formatEditUpdate(old, TextEditingValue(text: input)).text,
          input);
      expect(error, isNull);
    }
  });

  test('Valida importes, correo y teléfono con instrucciones concretas', () {
    for (final value in ['', '-1', '1,', 'abc', '1000000000']) {
      expect(validateRecordField('value', 'Valor', value), isNotNull);
    }
    for (final value in ['0', '0,00', '0.00', '0,01']) {
      expect(validateRecordField('value', 'Valor', value), isNull);
    }
    expect(
        validateRecordField('email', 'Correo', 'correo-invalido'), isNotNull);
    expect(
        validateRecordField('email', 'Correo', 'admin@grupocg.local'), isNull);
    expect(validateRecordField('phone', 'Teléfono', '-------'), isNotNull);
    expect(validateRecordField('phone', 'Teléfono', '+57 3001234567'), isNull);
  });

  testWidgets('Muestra errores y solo permite guardar un valor válido',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: RecordFormDialog(
      title: 'Cobro',
      fields: {'value': 'Valor en pesos', 'email': 'Correo'},
    ))));
    final value = find.byKey(const ValueKey('value'));
    await tester.enterText(value, '0');
    await tester.enterText(find.byKey(const ValueKey('email')), 'sin-correo');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(tester.state<FormFieldState<String>>(value).validate(), isTrue);
    expect(
        find.text('Escribe un correo válido, por ejemplo nombre@correo.com.'),
        findsOneWidget);
    await tester.enterText(value, '25000');
    await tester.pumpAndSettle();
    await tester.enterText(value, '25000abc');
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(value).controller!.text, '25000');
    expect(tester.state<FormFieldState<String>>(value).validate(), isFalse);
    expect(
        find.text(
            'Escribe solo números, sin letras, espacios ni símbolos de dinero.'),
        findsOneWidget);
    await tester.enterText(value, '25000,50');
    await tester.pumpAndSettle();
    expect(find.text('El valor debe ser mayor que cero.'), findsNothing);
    expect(
        find.text(
            'Escribe solo números, sin letras, espacios ni símbolos de dinero.'),
        findsNothing);
  });
}
