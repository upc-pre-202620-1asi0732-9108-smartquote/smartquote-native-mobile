import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../application/request_draft.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key, required this.services});
  final Services services;
  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends OperationState<NewRequestPage> {
  final _form = GlobalKey<FormState>();
  final draft = RequestDraft();
  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    final invalid = draft.validate();
    if (invalid != null) {
      setState(() => error = ApiFailure(invalid));
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
      appBar: AppBar(title: const Text('Nueva solicitud')),
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
                    title: const Text('Fecha requerida'),
                    subtitle: Text(
                      dateLabel(draft.requiredDate.toIso8601String()),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final now = DateUtils.dateOnly(DateTime.now());
                      final value = await showDatePicker(
                        context: context,
                        initialDate: draft.requiredDate,
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
                child: Text(busy ? 'Registrando…' : 'Registrar solicitud'),
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
