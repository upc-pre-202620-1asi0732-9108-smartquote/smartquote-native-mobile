import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/new_request_viewmodel.dart';

class NewRequestScreen extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NewRequestViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Nueva solicitud', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: viewModel.isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Indica ítems, fecha y al menos un requisito obligatorio por ítem.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    _buildGeneralInfoCard(context, viewModel),
                    const SizedBox(height: 16),
                    ...viewModel.items.asMap().entries.map((entry) => _buildItemCard(entry.key, entry.value, viewModel)).toList(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => viewModel.addItem(),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar ítem'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              bool success = await viewModel.submitRequest();
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud creada exitosamente')));
                                Navigator.pop(context); // Vuelve a la lista
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.errorMessage ?? 'Error')));
                              }
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Enviar solicitud'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0056B3)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGeneralInfoCard(BuildContext context, NewRequestViewModel vm) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: vm.requiredDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) vm.setDate(picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha requerida', border: OutlineInputBorder()),
                  child: Text(DateFormat('dd / MM / yyyy').format(vm.requiredDate)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: vm.priority,
                decoration: const InputDecoration(labelText: 'Prioridad', border: OutlineInputBorder()),
                items: ['Normal', 'Alta', 'Urgente'].map((String val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) { if (val != null) vm.setPriority(val); },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int itemIndex, ItemForm item, NewRequestViewModel vm) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ítems ${itemIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(flex: 2, child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  onSaved: (val) => item.description = val ?? '',
                  validator: (val) => val!.isEmpty ? 'Requerido' : null,
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onSaved: (val) => item.quantity = int.tryParse(val ?? '1') ?? 1,
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Unidad', border: OutlineInputBorder()),
                  onSaved: (val) => item.unitOfMeasure = val ?? '',
                )),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Requisitos técnicos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ...item.requirements.map((req) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Nombre del requisito', border: OutlineInputBorder()), onSaved: (val) => req.name = val ?? '')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: req.operator,
                            decoration: const InputDecoration(labelText: 'Operador', border: OutlineInputBorder()),
                            items: ['Igual a', 'Mayor a', 'Menor a'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (val) { if (val != null) req.operator = val; },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Valor esperado', border: OutlineInputBorder()), onSaved: (val) => req.expectedValue = val ?? '')),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Unidad', border: OutlineInputBorder()), onSaved: (val) => req.unitOfMeasure = val ?? '')),
                        Checkbox(value: req.isMandatory, onChanged: (val) { /* Por simplicidad en UI, dejamos true por defecto */ }),
                        const Text('Obligatorio', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )).toList(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => vm.addRequirement(itemIndex),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar requisito'),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}