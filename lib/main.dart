import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'api.dart';
import 'record_form.dart';
import 'document.dart';

void main() => runApp(const CobrosApp());

class CobrosApp extends StatelessWidget {
  const CobrosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grupo CG • Cobros',
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff006bb6)),
          scaffoldBackgroundColor: const Color(0xfff4f7fb),
          inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white)),
      home: const Home());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final api = Api();
  Map<String, dynamic> data = {
    'clients': [],
    'charges': [],
    'signatures': [],
    'bills': [],
    'issuer': {},
    'vehicles': [],
    'drivers': []
  };
  bool busy = false;
  int page = 0;
  String query = '';
  static const titles = [
    'Cobros',
    'Clientes',
    'Firmas',
    'Cuentas de cobro',
    'Datos del emisor',
    'Vehículos',
    'Conductores'
  ];
  Future<void> run(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    final result = await api.call('state');
    if (mounted) setState(() => data = Map<String, dynamic>.from(result));
  }

  Future<Map<String, String>?> form(String title, Map<String, String> fields,
      {Map<String, dynamic>? initial,
      Map<String, List<DropdownMenuItem<String>>> choices = const {}}) async {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => RecordFormDialog(
          title: title, fields: fields, initial: initial, choices: choices),
    );
  }

  List<DropdownMenuItem<String>> options(String name) => (data[name] as List)
      .map((v) => DropdownMenuItem(
          value: '${v['id']}', child: Text(v['name'] as String)))
      .toList();
  Future<void> edit(String entity, [Map<String, dynamic>? item]) async {
    final fields = switch (entity) {
      'clients' => {
          'name': 'Nombre / razón social',
          'document': 'NIT / cédula',
          'phone': 'Teléfono',
          'email': 'Correo',
          'address': 'Dirección'
        },
      'charges' => {
          'date': 'Fecha',
          'client_id': 'Cliente',
          'vehicle_id': 'Vehículo / placa',
          'driver_id': 'Conductor',
          'sheet': 'Planilla',
          'value': 'Valor en pesos'
        },
      'vehicles' => {'name': 'Placa', 'document': 'Marca / modelo'},
      'drivers' => {
          'name': 'Nombre del conductor',
          'document': 'Cédula',
          'phone': 'Teléfono'
        },
      'issuer' => {
          'name': 'Nombre / razón social',
          'document': 'NIT / cédula',
          'phone': 'Teléfono',
          'email': 'Correo',
          'address': 'Dirección',
          'city': 'Ciudad'
        },
      _ => {'name': 'Nombre del firmante', 'document': 'Cédula / NIT'},
    };
    final initial = {...?item};
    if (entity == 'charges') {
      initial['date'] ??= DateTime.now().toIso8601String().substring(0, 10);
      if (item != null) {
        initial['value'] = ((item['amount'] as num) / 100).toStringAsFixed(2);
      }
    }
    final values = await form(
        entity == 'issuer'
            ? 'Datos del emisor'
            : '${item == null ? 'Nuevo registro' : 'Editar registro'} · ${fields.values.first}',
        fields,
        initial: initial,
        choices: entity == 'charges'
            ? {
                'client_id': options('clients'),
                'vehicle_id': options('vehicles'),
                'driver_id': options('drivers')
              }
            : {});
    if (values == null) return;
    await run(() async {
      if (entity == 'signatures') {
        final file = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['png', 'jpg', 'jpeg'],
            withData: true);
        if (file == null) return;
        final bytes = file.files.single.bytes;
        if (bytes == null || bytes.length > 2 * 1024 * 1024) {
          throw Exception(
              'La firma debe ser una imagen PNG o JPG de máximo 2 MB.');
        }
        values['image'] = base64Encode(bytes);
      }
      await api.call('save', {
        'entity': entity,
        'record': {...values, if (item?['id'] != null) 'id': item!['id']}
      });
      await refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro guardado correctamente.')));
      }
    });
  }

  Future<void> generate() async {
    if ((data['clients'] as List).isEmpty ||
        (data['signatures'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Registra primero un cliente, una firma y los datos del emisor.')));
      return;
    }
    final values = await form('Generar cuenta de cobro', {
      'client_id': 'Cliente',
      'signature_id': 'Firma',
      'concept': 'Concepto / ruta'
    }, choices: {
      'client_id': options('clients'),
      'signature_id': options('signatures')
    });
    if (values == null || !mounted) return;
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Selecciona el periodo de cobro');
    if (range == null) return;
    await run(() async {
      final bill = await api.call('generate', {
        ...values,
        'from': range.start.toIso8601String().substring(0, 10),
        'to': range.end.toIso8601String().substring(0, 10)
      });
      await refresh();
      if (mounted) await preview(Map<String, dynamic>.from(bill));
    });
  }

  Future<void> preview(Map<String, dynamic> bill) async {
    final bytes = await buildDocument(bill);
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                appBar: AppBar(title: Text('Cuenta ${bill['number']}')),
                body: PdfPreview(
                    build: (_) async => bytes,
                    pdfFileName: 'Cuenta-${bill['number']}.pdf',
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    allowSharing: true))));
  }

  @override
  Widget build(BuildContext context) {
    if (api.token.isEmpty) {
      return Scaffold(
          body: Center(
              child: SizedBox(
                  width: 410,
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(32),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 58, color: Color(0xff006bb6)),
                            const SizedBox(height: 20),
                            Text('GRUPO CG',
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const Text('Planillas y cuentas de cobro'),
                            const SizedBox(height: 28),
                            if (busy) const LinearProgressIndicator(),
                            FilledButton.icon(
                                icon: const Icon(Icons.login),
                                label: const Text('Iniciar sesión'),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final v = await form('Acceso', {
                                          'email': 'Correo',
                                          'password': 'Contraseña'
                                        });
                                        if (v != null) {
                                          await run(() async {
                                            final response =
                                                await api.call('login', v);
                                            api.token = response['token'];
                                            try {
                                              await refresh();
                                            } catch (_) {
                                              api.token = '';
                                              rethrow;
                                            }
                                          });
                                        }
                                      })
                          ]))))));
    }
    final entity = [
      'charges',
      'clients',
      'signatures',
      'bills',
      'issuer',
      'vehicles',
      'drivers'
    ][page];
    final records = page == 4
        ? <dynamic>[]
        : (data[entity] as List)
            .where((r) =>
                jsonEncode(r).toLowerCase().contains(query.toLowerCase()))
            .toList();
    final total = (data['charges'] as List)
        .fold<num>(0, (sum, r) => sum + (r['amount'] as num));
    return Scaffold(
        appBar: AppBar(
            title: const Text('GRUPO CG'),
            backgroundColor: const Color(0xff006bb6),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  onPressed: busy ? null : () => run(refresh),
                  icon: const Icon(Icons.refresh)),
              IconButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                            await api.call('logout');
                            setState(() => api.token = '');
                          }),
                  icon: const Icon(Icons.logout))
            ]),
        drawer: Drawer(
            child: SafeArea(
                child: Column(children: [
          const ListTile(
              title: Text('Administración de cobros'),
              subtitle: Text('Grupo CG')),
          for (int i = 0; i < titles.length; i++)
            ListTile(
                selected: page == i,
                leading: Icon([
                  Icons.receipt_long,
                  Icons.people_outline,
                  Icons.draw_outlined,
                  Icons.picture_as_pdf_outlined,
                  Icons.business_outlined,
                  Icons.local_shipping_outlined,
                  Icons.badge_outlined
                ][i]),
                title: Text(titles[i]),
                onTap: () {
                  setState(() {
                    page = i;
                    query = '';
                  });
                  Navigator.pop(context);
                })
        ]))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  if (busy) const LinearProgressIndicator(),
                  Text(titles[page],
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(page == 0
                      ? '${(data['charges'] as List).length} registros · Total ${money(total)}'
                      : 'Gestiona la información de tus cuentas de cobro'),
                  const SizedBox(height: 24),
                  if (page != 4)
                    TextField(
                        decoration: const InputDecoration(
                            hintText: 'Buscar…',
                            prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setState(() => query = v)),
                  const SizedBox(height: 16),
                  if (page == 4)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((data['issuer'] as Map).isEmpty
                                      ? 'Configura los datos que aparecerán en tus documentos.'
                                      : (data['issuer'] as Map)
                                          .values
                                          .join('\n')),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => edit(
                                              'issuer',
                                              Map<String, dynamic>.from(
                                                  data['issuer'])),
                                      child:
                                          const Text('Editar datos del emisor'))
                                ])))
                  else if (records.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                            child: Text('No hay registros para mostrar.'))),
                  for (final raw in records)
                    Builder(builder: (_) {
                      final r = Map<String, dynamic>.from(raw);
                      return Card(
                          child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              leading: page == 2
                                  ? Image.memory(base64Decode(r['image']),
                                      width: 60, height: 40)
                                  : Icon(
                                      page == 0
                                          ? Icons.receipt_long
                                          : page == 1
                                              ? Icons.person_outline
                                              : Icons.picture_as_pdf,
                                      color: const Color(0xff006bb6)),
                              title: Text(page == 0
                                  ? 'Planilla ${r['sheet']}'
                                  : page == 3
                                      ? 'Cuenta ${r['number']}'
                                      : r['name']),
                              subtitle: Text(page == 0
                                  ? '${r['date']} · ${r['client_name']}\n${r['vehicle']} · ${r['driver']}'
                                  : page == 3
                                      ? '${r['client']['name']} · ${r['from']} al ${r['to']}'
                                      : r['document']),
                              isThreeLine: page == 0,
                              trailing: page == 0
                                  ? Text(money(r['amount']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                  : const Icon(Icons.chevron_right),
                              onTap: busy
                                  ? null
                                  : () => page == 3
                                      ? run(() => preview(r))
                                      : edit(entity, r)));
                    }),
                  const SizedBox(height: 80)
                ]))),
        floatingActionButton: page == 4
            ? null
            : FloatingActionButton.extended(
                onPressed:
                    busy ? null : () => page == 3 ? generate() : edit(entity),
                icon: Icon(page == 3 ? Icons.picture_as_pdf : Icons.add),
                label: Text(page == 3 ? 'Generar cuenta' : 'Nuevo')));
  }
}
