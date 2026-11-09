import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../application/request_draft.dart';
import '../domain/purchase_request.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({
    super.key,
    required this.services,
    this.existing,
    this.recurring = false,
  });
  final Services services;
  final PurchaseRequest? existing;
  final bool recurring;
  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends OperationState<NewRequestPage> {
  final _form = GlobalKey<FormState>();
  late final draft = widget.existing == null
      ? RequestDraft()
      : RequestDraft.fromJson(widget.existing!.data);
  int intervalDays = 7, offsetDays = 2;
  String zone = 'America/Lima';
  Future<void> submit() async {
    if (widget.recurring &&
        (intervalDays < 1 ||
            intervalDays > 3650 ||
            offsetDays < 0 ||
            offsetDays > 3650)) {
      setState(
        () => error = const ApiFailure(
          'La periodicidad debe ser de 1 a 3650 días y la anticipación de 0 a 3650 días.',
        ),
      );
      notice('Revisa la periodicidad y la anticipación de la programación.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final invalid = draft.validate();
    if (invalid != null) {
      setState(() => error = ApiFailure(invalid));
      return;
    }
    if (widget.recurring || widget.existing != null) {
      final saved = await perform(() async {
        if (widget.recurring) {
          final body = draft.toJson()..remove('requiredDate');
          await widget.services.workflows!.createSchedule({
            ...body,
            'startDate': draft.requiredDate.toIso8601String().substring(0, 10),
            'intervalDays': intervalDays,
            'requiredDateOffsetDays': offsetDays,
            'timeZoneId': zone,
          });
        } else {
          // Use the version of the form being edited, not a newer version silently fetched on save.
          await widget.services.workflows!.saveDraft(widget.existing!.id, {
            ...draft.toJson(),
            'expectedVersion': widget.existing!.version,
          });
        }
        return true;
      });
      if (saved == true && mounted) {
        Navigator.pop(context, widget.existing?.id ?? 'schedule');
      }
      return;
    }
    final created = await perform(
      () => widget.services.requests.create(draft.toJson()),
    );
    if (created != null && mounted) Navigator.pop(context, created.id);
  }

  Widget textField(
    String label,
    String initial,
    void Function(String) change, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: initial,
      decoration: fieldDecoration(label),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: change,
      validator: numeric
          ? (v) {
              final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
              return parsed == null || !parsed.isFinite || parsed <= 0
                  ? 'Ingresa una cantidad mayor a cero.'
                  : null;
            }
          : requiredValue,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recurring
              ? 'Programar solicitudes'
              : widget.existing != null
              ? 'Editar borrador'
              : 'Nueva solicitud',
        ),
      ),
      body: Form(
        key: _form,
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              ErrorNotice(error),
              const Text(
                'Registra lo que la granja necesita; no se inventan requisitos ni datos del proveedor.',
              ),
              InfoCard(
                title: 'Datos de la solicitud',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      widget.recurring
                          ? 'Primera fecha de generación'
                          : 'Fecha requerida',
                    ),
                    subtitle: Text(
                      dateLabel(draft.requiredDate.toIso8601String()),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final now = DateUtils.dateOnly(DateTime.now());
                      final value = await showDatePicker(
                        context: context,
                        initialDate: draft.requiredDate.isBefore(now)
                            ? now
                            : draft.requiredDate,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 730)),
                      );
                      if (value != null) {
                        setState(() => draft.requiredDate = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: draft.priority,
                    decoration: fieldDecoration('Prioridad'),
                    items: priorityLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => draft.priority = v!,
                  ),
                ],
              ),
              if (widget.recurring)
                InfoCard(
                  title: 'Periodicidad',
                  children: [
                    const Text(
                      'Cada ocurrencia genera un borrador privado. Debes revisarlo y confirmar su envío; nunca se emiten órdenes automáticamente.',
                    ),
                    TextFormField(
                      initialValue: '7',
                      decoration: fieldDecoration('Generar cada (días)'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) >= 1 &&
                              (int.tryParse(v ?? '') ?? 3651) <= 3650
                          ? null
                          : 'Ingresa entre 1 y 3650 días.',
                      onChanged: (v) => intervalDays = int.tryParse(v) ?? 0,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: '2',
                      decoration: fieldDecoration(
                        'Días desde generación hasta fecha requerida',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? -1) >= 0 &&
                              (int.tryParse(v ?? '') ?? 3651) <= 3650
                          ? null
                          : 'Ingresa entre 0 y 3650 días.',
                      onChanged: (v) => offsetDays = int.tryParse(v) ?? -1,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Zona horaria de operación: America/Lima (Perú).',
                    ),
                  ],
                ),
              for (var i = 0; i < draft.items.length; i++)
                itemCard(draft.items[i], i),
              OutlinedButton.icon(
                onPressed: () => setState(() => draft.items.add(ItemDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Agregar ítem'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: submit,
                child: Text(
                  busy
                      ? 'Guardando…'
                      : widget.recurring
                      ? 'Guardar programación'
                      : widget.existing != null
                      ? 'Guardar borrador sin enviar'
                      : 'Registrar solicitud',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Después del registro puedes añadir un PDF o una imagen de sustento desde el detalle de la solicitud.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget itemCard(ItemDraft item, int index) => InfoCard(
    key: ValueKey(item),
    title: 'Ítem ${index + 1}',
    children: [
      textField('Descripción', item.description, (v) => item.description = v),
      textField(
        'Cantidad',
        item.quantity,
        (v) => item.quantity = v,
        numeric: true,
      ),
      textField('Unidad (kg, dosis, unidad…)', item.unit, (v) => item.unit = v),
      for (var i = 0; i < item.requirements.length; i++)
        requirementCard(item, item.requirements[i], i),
      TextButton.icon(
        onPressed: () =>
            setState(() => item.requirements.add(RequirementDraft())),
        icon: const Icon(Icons.add),
        label: const Text('Agregar requisito'),
      ),
      if (draft.items.length > 1)
        TextButton(
          onPressed: () => setState(() => draft.items.remove(item)),
          child: const Text('Quitar ítem'),
        ),
    ],
  );
  Widget requirementCard(ItemDraft item, RequirementDraft r, int index) => Card(
    key: ValueKey(r),
    color: const Color(0xffeaf0f4),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Requisito ${index + 1}'),
          const SizedBox(height: 12),
          textField('Nombre del requisito', r.name, (v) => r.name = v),
          DropdownButtonFormField<String>(
            initialValue: r.operator,
            isExpanded: true,
            decoration: fieldDecoration('Operador'),
            items: operatorLabels.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => r.operator = v!),
          ),
          const SizedBox(height: 12),
          textField(
            'Valor esperado',
            r.expectedValue,
            (v) => r.expectedValue = v,
          ),
          TextFormField(
            initialValue: r.unit,
            decoration: fieldDecoration('Unidad del requisito (opcional)'),
            onChanged: (v) => r.unit = v,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Obligatorio'),
            value: r.mandatory,
            onChanged: (v) => setState(() => r.mandatory = v!),
          ),
          if (item.requirements.length > 1)
            TextButton(
              onPressed: () => setState(() => item.requirements.remove(r)),
              child: const Text('Quitar requisito'),
            ),
        ],
      ),
    ),
  );
}
