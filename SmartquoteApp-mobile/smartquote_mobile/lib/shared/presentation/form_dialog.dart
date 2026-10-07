import 'package:flutter/material.dart';

import 'ui.dart';

Future<Map<String, String>?> dataDialog(
  BuildContext context,
  String title,
  List<(String, String, String)> fields,
) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => _DataDialog(title: title, fields: fields),
);

class _DataDialog extends StatefulWidget {
  const _DataDialog({required this.title, required this.fields});
  final String title;
  final List<(String, String, String)> fields;
  @override
  State<_DataDialog> createState() => _DataDialogState();
}

class _DataDialogState extends State<_DataDialog> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields) f.$1: TextEditingController(text: f.$3),
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: controllers[f.$1],
                  decoration: fieldDecoration(f.$2),
                  validator: f.$1 == 'unitOfMeasure' ? null : requiredValue,
                  maxLines:
                      [
                        'reason',
                        'sourceTextReference',
                        'deliveryConditions',
                        'address',
                      ].contains(f.$1)
                      ? 3
                      : 1,
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              for (final e in controllers.entries) e.key: e.value.text.trim(),
            });
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
