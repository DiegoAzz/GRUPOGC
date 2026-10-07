import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'bill_columns.dart';

String money(num cents) =>
    NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 2)
        .format(cents / 100);
String words(int n) {
  const units = [
    'cero',
    'uno',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
    'diez',
    'once',
    'doce',
    'trece',
    'catorce',
    'quince',
    'dieciséis',
    'diecisiete',
    'dieciocho',
    'diecinueve',
    'veinte',
    'veintiuno',
    'veintidós',
    'veintitrés',
    'veinticuatro',
    'veinticinco',
    'veintiséis',
    'veintisiete',
    'veintiocho',
    'veintinueve'
  ];
  if (n < 30) return units[n];
  if (n < 100) {
    return '${[
      '',
      '',
      '',
      'treinta',
      'cuarenta',
      'cincuenta',
      'sesenta',
      'setenta',
      'ochenta',
      'noventa'
    ][n ~/ 10]}${n % 10 == 0 ? '' : ' y ${words(n % 10)}'}';
  }
  if (n == 100) return 'cien';
  if (n < 1000) {
    return '${[
      '',
      'ciento',
      'doscientos',
      'trescientos',
      'cuatrocientos',
      'quinientos',
      'seiscientos',
      'setecientos',
      'ochocientos',
      'novecientos'
    ][n ~/ 100]}${n % 100 == 0 ? '' : ' ${words(n % 100)}'}';
  }
  if (n < 1000000) {
    return '${n ~/ 1000 == 1 ? '' : '${words(n ~/ 1000)} '}mil${n % 1000 == 0 ? '' : ' ${words(n % 1000)}'}';
  }
  return '${n ~/ 1000000 == 1 ? 'un millón' : '${words(n ~/ 1000000)} millones'}${n % 1000000 == 0 ? '' : ' ${words(n % 1000000)}'}';
}

Future<Uint8List> buildDocument(Map<String, dynamic> bill) async {
  final doc = pw.Document();
  final client = bill['client'] as Map<String, dynamic>;
  final issuer = bill['issuer'] as Map<String, dynamic>;
  final rows = (bill['rows'] as List).cast<Map<String, dynamic>>();
  final total = (bill['total'] as num).toInt();
  final columns = billColumns(bill);
  final equivalent = bill['template'] == 'equivalent_v1';
  final recipient = equivalent ? bill['recipient'] as Map : client;
  final date = DateTime.parse(bill['date'] as String);
  const months = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE'
  ];
  final headingDate = equivalent
      ? '${bill['document_city']}, ${date.day} DE ${months[date.month - 1]} DEL ${date.year}'
      : '${issuer['city']}, ${bill['date']}';
  doc.addPage(pw.MultiPage(
      pageFormat:
          columns.length > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(42),
      footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
              'Cuenta ${bill['number']} · ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9))),
      build: (_) => [
            pw.Center(child: pw.Text(headingDate)),
            pw.SizedBox(height: 24),
            pw.Center(
                child: pw.Text(
                    equivalent
                        ? 'DOCUMENTO EQUIVALENTE A FACTURA\nN°${bill['number']}'
                        : 'CUENTA DE COBRO N.º ${bill['number']}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: equivalent ? 14 : 17,
                        fontWeight: pw.FontWeight.bold))),
            if (equivalent) ...[
              pw.SizedBox(height: 6),
              pw.Center(child: pw.Text(bill['legal_legend'] as String)),
            ],
            pw.SizedBox(height: 24),
            pw.Center(
                child: pw.Text(
                    '${recipient['name']}\n${equivalent ? 'NIT:' : 'NIT / CC:'} ${recipient['document']}',
                    textAlign: pw.TextAlign.center)),
            pw.SizedBox(height: 24),
            pw.Center(
                child: pw.Text(
                    'Debe a:\n${issuer['name']}\nNIT / CC: ${issuer['document']}\n${issuer['phone']}\n${issuer['address']}\n${issuer['email']}',
                    textAlign: pw.TextAlign.center)),
            pw.SizedBox(height: 24),
            if (equivalent) ...[
              pw.Center(child: pw.Text('Por concepto de:')),
              pw.SizedBox(height: 12),
              pw.Center(
                  child: pw.Text((bill['concept'] as String).toUpperCase())),
              pw.SizedBox(height: 8),
              pw.Center(
                  child: pw.Text(
                      '(${NumberFormat(total % 100 == 0 ? '#,##0' : '#,##0.00', 'es_CO').format(total / 100)})')),
              pw.SizedBox(height: 8),
              pw.Center(
                  child: pw.Text(
                      '${words(total ~/ 100).toUpperCase()}${total % 100 == 0 ? '' : ' CON ${(total % 100).toString().padLeft(2, '0')}/100'}',
                      textAlign: pw.TextAlign.center)),
            ] else ...[
              pw.Text('Por concepto de: ${bill['concept']}'),
              pw.Text('Periodo: ${bill['from']} al ${bill['to']}'),
              pw.SizedBox(height: 14),
              pw.Text(money(total),
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  '${words(total ~/ 100).toUpperCase()} PESOS CON ${(total % 100).toString().padLeft(2, '0')}/100'),
            ],
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
                headers: columns.map((c) => c['label'].toString()).toList(),
                data: rows
                    .map((r) => [
                          for (final c in columns)
                            c['key'] == 'amount'
                                ? money(r['amount'] as num)
                                : standardBillColumns.containsKey(c['key'])
                                    ? '${r[c['key']] ?? ''}'
                                    : '${(r['custom_values'] as Map?)?[c['key']] ?? ''}'
                        ])
                    .toList(),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blue100),
                cellStyle: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('TOTAL: ${money(total)}')),
            pw.SizedBox(height: 25),
            pw.Image(
                pw.MemoryImage(
                    base64Decode(bill['signature']['image'] as String)),
                height: 70,
                width: 180,
                fit: pw.BoxFit.contain),
            pw.Text(
                '${bill['signature']['name']}\n${bill['signature']['document']}'),
          ]));
  return doc.save();
}
