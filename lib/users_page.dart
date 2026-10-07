import 'package:flutter/material.dart';
import 'api.dart';
import 'record_form.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.api, required this.adminId});
  final Api api;
  final int adminId;
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> users = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    perform(load);
  }

  Future<void> load() async {
    final result = await widget.api.call('users_list');
    if (mounted) setState(() => users = result as List);
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const RecordFormDialog(title: 'Crear usuario', fields: {
              'email': 'Correo',
              'password': 'Contraseña (mínimo 8 caracteres)'
            }));
    if (values == null || !mounted) return;
    await perform(() async {
      await widget.api.call('create_user', values);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Usuario creado. Ya puede iniciar sesión.')));
      }
    });
  }

  Future<void> remove(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('¿Eliminar usuario?'),
              content: Text(
                  'Se quitará el acceso de ${user['email']} y se cerrarán sus sesiones. Los datos de la empresa se conservarán.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    await perform(() async {
      await widget.api.call('delete_user', {'id': user['id']});
      await load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Usuarios'), actions: [
          IconButton(
              tooltip: 'Actualizar usuarios',
              onPressed: busy ? null : () => perform(load),
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text(
              'Los usuarios tienen acceso a los datos compartidos de la empresa. Solo la cuenta administradora puede gestionar accesos.'),
          if (busy) const LinearProgressIndicator(),
          for (final user in users)
            Card(
                child: ListTile(
              title: Text(user['email'] as String),
              subtitle: Text(
                  user['id'] == widget.adminId ? 'Administrador' : 'Usuario'),
              trailing: user['id'] == widget.adminId
                  ? null
                  : IconButton(
                      tooltip: 'Eliminar usuario',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () => remove(Map<String, dynamic>.from(user))),
            )),
          const SizedBox(height: 80),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: busy ? null : create,
            icon: const Icon(Icons.person_add),
            label: const Text('Crear usuario')),
      );
}
