import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/api_contract.dart';

const statusLabels = {
  'Submitted': 'Enviada',
  'UnderReview': 'En revisión',
  'QuotationCollection': 'Recepción de cotizaciones',
  'Evaluation': 'En evaluación',
  'Approved': 'Aprobada',
  'Ordered': 'Orden emitida',
  'Rejected': 'Rechazada',
  'Cancelled': 'Cancelada',
  'Uploaded': 'Cargada',
  'Processing': 'Procesando',
  'RequiresVerification': 'Por verificar',
  'Verified': 'Verificada',
  'Unresolved': 'No resuelto',
  'Resolved': 'Resuelto',
  'Confirmed': 'Confirmado',
  'Corrected': 'Corregido',
  'Issued': 'Emitida',
  'Delivered': 'Entregada',
  'Pending': 'Pendiente',
  'Active': 'Activa',
};
const operatorLabels = {
  'Equals': 'Igual a',
  'GreaterThanOrEqual': 'Mayor o igual que',
  'LessThanOrEqual': 'Menor o igual que',
  'Contains': 'Contiene',
};
const priorityLabels = {
  'Normal': 'Normal',
  'High': 'Alta',
  'Emergency': 'Emergencia',
};
String labelOf(String value) => statusLabels[value] ?? value;
String shortId(String value) =>
    value.length <= 8 ? value : value.substring(0, 8);
String money(num? value, String currency) => value == null
    ? 'No disponible'
    : '$currency ${NumberFormat('#,##0.00', 'es_PE').format(value)}';
String dateLabel(String? value, {bool time = false}) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return '—';
  return DateFormat(time ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy')
      .format(date.toLocal());
}

String friendlyExplanation(String value) {
  var result = value
      .replaceAll('does not satisfy', 'no cumple')
      .replaceAll('satisfies', 'cumple')
      .replaceAll('N/A', 'sin evidencia');
  for (final entry in operatorLabels.entries) {
    result = result.replaceAll(entry.key, entry.value.toLowerCase());
  }
  return result;
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = ['Rejected', 'Cancelled', 'Unresolved'].contains(status)
        ? const Color(0xffc5221f)
        : [
            'Verified',
            'Issued',
            'Ordered',
            'Delivered',
            'Confirmed',
          ].contains(status)
        ? const Color(0xff1e8e3e)
        : const Color(0xff0f5b8c);
    return Chip(
      label: Text(labelOf(status)),
      backgroundColor: color.withValues(alpha: .1),
      labelStyle: TextStyle(color: color),
      side: BorderSide.none,
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.error, {super.key, this.onRetry});
  final Object? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final trace = error is ApiFailure ? (error as ApiFailure).traceId : '';
    return Card(
      color: const Color(0xfffbe9e9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(error.toString()),
            if (trace.isNotEmpty) SelectableText('Referencia: $trace'),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Actualizar')),
          ],
        ),
      ),
    );
  }
}

InputDecoration fieldDecoration(String label) =>
    InputDecoration(labelText: label);
String? requiredValue(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este campo.' : null;

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;
