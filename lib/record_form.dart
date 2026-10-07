import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reject the entire edit instead of silently changing a pasted monetary value.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter(this.onValidation);
  final ValueChanged<String?> onValidation;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (RegExp(r'^([0-9]{1,9}([,.][0-9]{0,2})?)?$').hasMatch(text)) {
      onValidation(null);
      return newValue;
    }
    onValidation(RegExp(r'[^0-9,.]').hasMatch(text)
        ? 'Escribe solo números, sin letras, espacios ni símbolos de dinero.'
        : 'Usa hasta 9 dígitos y 2 decimales, sin separadores de miles.');
    return oldValue;
  }
}

String? validateRecordField(String field, String label, String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Completa el campo $label.';
  if (value.length > 500) return 'Usa como máximo 500 caracteres.';
  if (field == 'value') {
    if (!RegExp(r'^[0-9]{1,9}([,.][0-9]{1,2})?$').hasMatch(value)) {
      return 'Escribe un valor como 25000 o 25000,50.';
    }
    if (double.parse(value.replaceAll(',', '.')) <= 0) {
      return 'El valor debe ser mayor que cero.';
    }
  }
  if (field == 'email' &&
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
    return 'Escribe un correo válido, por ejemplo nombre@correo.com.';
  }
  if (field == 'phone' &&
      (!RegExp(r'^\+?[0-9 ()-]{7,25}$').hasMatch(value) ||
          value.replaceAll(RegExp(r'[^0-9]'), '').length < 7 ||
          value.replaceAll(RegExp(r'[^0-9]'), '').length > 15)) {
    return 'Escribe un teléfono válido, por ejemplo 3001234567.';
  }
  return null;
}

class RecordFormDialog extends StatefulWidget {
  const RecordFormDialog(
      {super.key,
      required this.title,
      required this.fields,
      this.initial,
      this.onDelete,
      this.choices = const {}});
  final String title;
  final Map<String, String> fields;
  final Map<String, dynamic>? initial;
  final VoidCallback? onDelete;
  final Map<String, List<DropdownMenuItem<String>>> choices;

  @override
  State<RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<RecordFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controls;
  String? amountInputError;
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    controls = {
      for (final k in widget.fields.keys)
        k: TextEditingController(text: widget.initial?[k]?.toString() ?? '')
    };
  }

  @override
  void dispose() {
    for (final controller in controls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Form(
              key: formKey,
              autovalidateMode: submitted
                  ? AutovalidateMode.always
                  : AutovalidateMode.onUserInteraction,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final field in widget.fields.entries)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: widget.choices.containsKey(field.key)
                          ? DropdownButtonFormField<String>(
                              key: ValueKey(field.key),
                              initialValue: controls[field.key]!.text.isEmpty
                                  ? null
                                  : controls[field.key]!.text,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: field.value,
                                  errorMaxLines: 3,
                                  helperText: widget.choices[field.key]!.isEmpty
                                      ? 'Primero registra ${field.value.toLowerCase()} en su módulo.'
                                      : null,
                                  helperMaxLines: 3),
                              items: widget.choices[field.key],
                              onChanged: (v) =>
                                  controls[field.key]!.text = v ?? '',
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Selecciona ${field.value.toLowerCase()}.'
                                  : null,
                            )
                          : TextFormField(
                              key: ValueKey(field.key),
                              controller: controls[field.key],
                              obscureText: field.key == 'password',
                              keyboardType: switch (field.key) {
                                'value' =>
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                                'email' => TextInputType.emailAddress,
                                'phone' => TextInputType.phone,
                                _ => TextInputType.text,
                              },
                              inputFormatters: field.key == 'value'
                                  ? [
                                      AmountInputFormatter((error) {
                                        if (amountInputError != error) {
                                          setState(
                                              () => amountInputError = error);
                                        }
                                      })
                                    ]
                                  : null,
                              decoration: InputDecoration(
                                  labelText: field.value,
                                  errorMaxLines: 3,
                                  prefixText:
                                      field.key == 'value' ? '\$ ' : null,
                                  helperText: field.key == 'value'
                                      ? 'Ejemplo: 25000 o 25000,50. Sin separadores de miles.'
                                      : null,
                                  helperMaxLines: 3,
                                  errorText: field.key == 'value'
                                      ? amountInputError
                                      : null),
                              validator: (v) => field.key == 'value' &&
                                      amountInputError != null
                                  ? amountInputError
                                  : validateRecordField(
                                      field.key, field.value, v),
                              readOnly: field.key == 'date',
                              onTap: field.key == 'date'
                                  ? () async {
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.tryParse(
                                                  controls[field.key]!.text) ??
                                              DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100));
                                      if (picked != null && mounted) {
                                        controls[field.key]!.text = picked
                                            .toIso8601String()
                                            .substring(0, 10);
                                      }
                                    }
                                  : null,
                            )),
                if (submitted)
                  const Text('Revisa los campos señalados antes de guardar.',
                      style: TextStyle(color: Colors.red)),
              ]),
            ))),
        actions: [
          if (widget.onDelete != null)
            TextButton.icon(
                onPressed: widget.onDelete,
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    for (final entry in controls.entries)
                      entry.key: entry.value.text.trim()
                  });
                } else {
                  setState(() => submitted = true);
                }
              },
              child: const Text('Guardar')),
        ],
      );
}
