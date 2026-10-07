import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'api.dart';

class PlanillaPhotosPage extends StatefulWidget {
  const PlanillaPhotosPage({super.key, required this.api});
  final Api api;
  @override
  State<PlanillaPhotosPage> createState() => _PlanillaPhotosPageState();
}

class _PlanillaPhotosPageState extends State<PlanillaPhotosPage> {
  List<Map<String, dynamic>> photos = [];
  bool busy = false;
  String search = '';
  @override
  void initState() {
    super.initState();
    run(load);
  }

  Future<void> run(Future<void> Function() action) async {
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

  Future<void> load() async {
    final state = await widget.api.call('state') as Map<String, dynamic>;
    if (mounted) {
      setState(() => photos = (state['planilla_photos'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
    }
  }

  Future<void> create([String? sheet]) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => PhotoEntryDialog(initialSheet: sheet));
    if (result == null || !mounted) return;
    await run(() async {
      var saved = 0;
      final images = result['images'] as List;
      try {
        for (final image in images) {
          await widget.api
              .call('save_photo', {'sheet': result['sheet'], 'image': image});
          saved++;
        }
      } catch (e) {
        throw Exception(
            'Se guardaron $saved de ${images.length} fotos. ${e.toString().replaceFirst('Exception: ', '')}');
      } finally {
        await load();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$saved fotos de planilla guardadas.')));
      }
    });
  }

  Future<void> showPhoto(Map<String, dynamic> item) async {
    await run(() async {
      final photo = await widget.api.call('photo_get', {'id': item['id']})
          as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('Planilla ${photo['sheet']}')),
                  body: InteractiveViewer(
                      child: Center(
                          child: Image.memory(
                              base64Decode(photo['image'] as String)))))));
    });
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('¿Eliminar foto?'),
                content: Text(
                    'Se eliminará la foto de la planilla ${item['sheet']}.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'))
                ]));
    if (confirmed != true || !mounted) return;
    await run(() async {
      await widget.api
          .call('delete', {'entity': 'planilla_photos', 'id': item['id']});
      await load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final photo in photos) {
      final sheet = photo['sheet'] as String;
      if (sheet.toLowerCase().contains(search)) {
        groups.putIfAbsent(sheet, () => []).add(photo);
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos de planillas'), actions: [
        IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : () => run(load),
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (busy) const LinearProgressIndicator(),
        TextField(
            decoration: const InputDecoration(
                labelText: 'Buscar número de planilla',
                prefixIcon: Icon(Icons.search)),
            onChanged: (text) =>
                setState(() => search = text.trim().toLowerCase())),
        const SizedBox(height: 16),
        for (final group in groups.entries)
          Card(
              child: ExpansionTile(
            leading: const Icon(Icons.photo_outlined),
            title: Text('Planilla ${group.key}'),
            subtitle: Text('${group.value.length} fotos'),
            children: [
              for (var i = 0; i < group.value.length; i++)
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text('Foto ${i + 1}'),
                  subtitle: Text(group.value[i]['created_at']
                          ?.toString()
                          .split('T')
                          .first ??
                      ''),
                  trailing: IconButton(
                      tooltip: 'Eliminar foto',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => remove(group.value[i])),
                  onTap: busy ? null : () => showPhoto(group.value[i]),
                ),
              TextButton.icon(
                onPressed: busy ? null : () => create(group.key),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Añadir fotos'),
              ),
            ],
          )),
        if (photos.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aún no hay fotos de planillas.'))),
        const SizedBox(height: 80),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : create,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Añadir fotos')),
    );
  }
}

class PhotoEntryDialog extends StatefulWidget {
  const PhotoEntryDialog({super.key, this.initialSheet});
  final String? initialSheet;
  @override
  State<PhotoEntryDialog> createState() => _PhotoEntryDialogState();
}

class _PhotoEntryDialogState extends State<PhotoEntryDialog> {
  late final sheet = TextEditingController(text: widget.initialSheet);
  final List<Uint8List> images = [];
  bool processing = false;
  String? error;

  @override
  void dispose() {
    sheet.dispose();
    super.dispose();
  }

  Future<void> choose(bool camera) async {
    setState(() {
      processing = true;
      error = null;
    });
    try {
      final sources = <Uint8List>[];
      if (camera) {
        final source = await Navigator.push<Uint8List>(context,
            MaterialPageRoute(builder: (_) => const CameraCapturePage()));
        if (source != null) sources.add(source);
      } else {
        final files = await ImagePicker()
            .pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
        for (final file in files) {
          sources.add(await file.readAsBytes());
        }
      }
      for (final source in sources) {
        final decoded = img.decodeImage(source);
        if (decoded == null) {
          throw Exception('Selecciona una imagen JPG o PNG.');
        }
        final oriented = img.bakeOrientation(decoded);
        final resized = oriented.width > 1600 || oriented.height > 1600
            ? img.copyResize(oriented,
                width: oriented.width >= oriented.height ? 1600 : null,
                height: oriented.height > oriented.width ? 1600 : null)
            : oriented;
        final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: 82));
        if (encoded.length > 2 * 1024 * 1024) {
          throw Exception(
              'La imagen comprimida supera 2 MB. Escoge una foto más pequeña.');
        }
        if (mounted) setState(() => images.add(encoded));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Fotos de planilla'),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: sheet,
                  maxLength: 500,
                  decoration:
                      const InputDecoration(labelText: 'Número de planilla')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: processing ? null : () => choose(true),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Tomar foto')),
                OutlinedButton.icon(
                    onPressed: processing ? null : () => choose(false),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Subir imágenes')),
              ]),
              if (processing)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()),
              Text('${images.length} fotos seleccionadas'),
              for (var i = 0; i < images.length; i++)
                ListTile(
                  leading: Image.memory(images[i],
                      width: 60, height: 60, fit: BoxFit.cover),
                  title: Text('Foto ${i + 1}'),
                  trailing: IconButton(
                    tooltip: 'Quitar foto seleccionada',
                    onPressed: processing
                        ? null
                        : () => setState(() => images.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: processing
                  ? null
                  : () {
                      if (sheet.text.trim().isEmpty || images.isEmpty) {
                        setState(() => error =
                            'Escribe el número de planilla y selecciona una foto.');
                        return;
                      }
                      Navigator.pop(context, {
                        'sheet': sheet.text.trim(),
                        'images': images.map(base64Encode).toList()
                      });
                    },
              child: const Text('Guardar'))
        ],
      );
}

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});
  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? controller;
  String? error;
  bool taking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    open();
  }

  Future<void> open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No hay cámara disponible.');
      final preferred = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back);
      final camera = CameraController(
          preferred.isNotEmpty ? preferred.first : cameras.first,
          ResolutionPreset.medium,
          enableAudio: false);
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => controller = camera);
    } catch (e) {
      if (mounted) setState(() => error = 'No se pudo abrir la cámara: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && controller != null) {
      controller!.dispose();
      controller = null;
    }
    if (state == AppLifecycleState.resumed &&
        controller == null &&
        error == null) {
      open();
    }
  }

  Future<void> capture() async {
    final camera = controller;
    if (camera == null || taking) return;
    setState(() => taking = true);
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) setState(() => error = 'No se pudo tomar la foto: $e');
    } finally {
      if (mounted) setState(() => taking = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tomar foto')),
        body: Center(
            child: error != null
                ? Text(error!, textAlign: TextAlign.center)
                : controller == null
                    ? const CircularProgressIndicator()
                    : CameraPreview(controller!)),
        floatingActionButton: error != null
            ? null
            : FloatingActionButton.extended(
                onPressed: taking ? null : capture,
                icon: const Icon(Icons.camera),
                label: const Text('Capturar')),
      );
}
