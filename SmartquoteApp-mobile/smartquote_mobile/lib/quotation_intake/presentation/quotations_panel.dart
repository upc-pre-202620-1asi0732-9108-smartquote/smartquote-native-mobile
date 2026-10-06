import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/infrastructure/file_selection.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../supply_requests/domain/purchase_request.dart';
import '../application/upload_queue.dart';
import '../domain/quotation.dart';
import 'quotation_review_page.dart';

class QuotationsPanel extends StatefulWidget {
  const QuotationsPanel({
    super.key,
    required this.services,
    required this.request,
    required this.active,
    required this.onChanged,
    required this.onBusy,
  });
  final Services services;
  final PurchaseRequest request;
  final bool active;
  final Future<void> Function() onChanged;
  final void Function(bool) onBusy;
  @override
  State<QuotationsPanel> createState() => _QuotationsPanelState();
}

class _QuotationsPanelState extends OperationState<QuotationsPanel> {
  List<Quotation> quotes = [];
  late final UploadQueue queue;
  @override
  void initState() {
    super.initState();
    queue = UploadQueue(widget.services.quotations, widget.request.id);
    queue.addListener(updateQueue);
    if (widget.active) load();
  }

  void updateQueue() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(QuotationsPanel old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) load();
  }

  @override
  void dispose() {
    queue.removeListener(updateQueue);
    queue.dispose();
    super.dispose();
  }

  Future<void> load() async {
    await perform(() async {
      quotes = await widget.services.quotations.list(widget.request.id);
    });
  }

  Future<void> upload() async {
    widget.onBusy(true);
    await perform(() async {
      final files = await selectFiles(multiple: true, quotation: true);
      if (files.isEmpty) return;
      final existing = await widget.services.quotations.list(widget.request.id);
      await queue.start(files, {}, knownIds: existing.map((q) => q.id).toSet());
      quotes = await widget.services.quotations.list(widget.request.id);
    });
    widget.onBusy(false);
  }

  Future<void> ready() async {
    widget.onBusy(true);
    final done = await perform(() async {
      final request = await widget.services.requests.get(widget.request.id);
      await widget.services.requests.changeStatus(
        request,
        'Evaluation',
        'Al menos dos cotizaciones verificadas; inicio de evaluación.',
      );
      return true;
    });
    widget.onBusy(false);
    if (done == true) await widget.onChanged();
  }

  Future<void> review(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationReviewPage(
          services: widget.services,
          request: widget.request,
          quotationId: id,
        ),
      ),
    );
    if (mounted) {
      await load();
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (busy && !queue.running) const LinearProgressIndicator(),
      ErrorNotice(error, onRetry: load),
      const Text(
        'Carga los PDF. El proveedor se obtiene del documento y los datos deben verificarse antes de comparar.',
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed:
            busy ||
                queue.running ||
                widget.request.status != 'QuotationCollection'
            ? null
            : upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Cargar y procesar cotizaciones'),
      ),
      Text(
        'Máximo 20 PDF por selección, 15 MB por archivo. Se procesan como máximo dos a la vez.',
      ),
      if (widget.request.status != 'QuotationCollection')
        const Text(
          'La recepción debe estar habilitada para cargar documentos.',
        ),
      for (final entry in queue.entries)
        InfoCard(
          title: entry.file.name,
          children: [
            Text(entry.stage),
            if (entry.duplicate)
              const Text(
                'Documento ya registrado: se utiliza la cotización existente, sin duplicarla.',
              ),
            if (['Cargando', 'Procesando con IA'].contains(entry.stage))
              LinearProgressIndicator(value: entry.progress),
            if (entry.stage == 'Procesando con IA')
              const Text(
                'La duración depende del documento y del servicio de IA; no se estima un tiempo ficticio.',
              ),
            ErrorNotice(entry.error),
            if (entry.error != null)
              TextButton(
                onPressed: queue.running
                    ? null
                    : () async {
                        widget.onBusy(true);
                        await queue.retry(entry);
                        widget.onBusy(false);
                        if (mounted) await load();
                      },
                child: const Text('Reintentar este documento'),
              ),
            if (entry.quotationId != null &&
                ['Lista para verificar', 'Ya verificada'].contains(entry.stage))
              TextButton(
                onPressed: () => review(entry.quotationId!),
                child: const Text('Ver datos del documento'),
              ),
          ],
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${quotes.length} cotizaciones'),
          IconButton(
            tooltip: 'Actualizar cotizaciones',
            onPressed: busy || queue.running ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      for (final quote in quotes)
        Card(
          child: ListTile(
            title: Text(
              textOf(quote.data, 'supplierBusinessName').isEmpty
                  ? textOf(quote.data, 'fileName')
                  : textOf(quote.data, 'supplierBusinessName'),
            ),
            subtitle: Text(
              '${labelOf(quote.status)} · ${money(quote.total, textOf(quote.data, 'currency'))}\n${textOf(quote.data, 'fileName')}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => review(quote.id),
          ),
        ),
      if (quotes.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay cotizaciones cargadas.'),
        ),
      if (widget.request.status == 'QuotationCollection' &&
          quotes.where((q) => q.verified).length >= 2)
        FilledButton(
          onPressed: busy || queue.running ? null : ready,
          child: const Text('Cotizaciones listas: pasar a evaluación'),
        ),
    ],
  );
}
