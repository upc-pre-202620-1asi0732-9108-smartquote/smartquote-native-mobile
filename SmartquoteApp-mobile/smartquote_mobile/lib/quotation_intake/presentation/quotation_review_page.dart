import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/domain/api_contract.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../../shared/presentation/form_dialog.dart';
import '../../supply_requests/domain/purchase_request.dart';
import '../domain/quotation.dart';

class QuotationReviewPage extends StatefulWidget {
  const QuotationReviewPage({
    super.key,
    required this.services,
    required this.request,
    required this.quotationId,
  });
  final Services services;
  final PurchaseRequest request;
  final String quotationId;
  @override
  State<QuotationReviewPage> createState() => _QuotationReviewPageState();
}

class _QuotationReviewPageState extends OperationState<QuotationReviewPage> {
  Quotation? quote;
  bool allFields = false, mappingsReviewed = false;
  final mappings = <String, String>{};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> fetch() async {
    quote = await widget.services.quotations.get(widget.quotationId);
    for (final line in quote!.lines) {
      final id = textOf(line, 'lineId');
      final stored = textOf(line, 'requestedItemId');
      if (stored.isNotEmpty) {
        mappings[id] = stored;
      } else if (!mappings.containsKey(id)) {
        if (widget.request.items.length == 1) {
          mappings[id] = textOf(widget.request.items.first, 'itemId');
        } else {
          final matches = widget.request.items
              .where(
                (i) =>
                    textOf(i, 'description').trim().toLowerCase() ==
                    textOf(line, 'description').trim().toLowerCase(),
              )
              .toList();
          if (matches.length == 1) {
            mappings[id] = textOf(matches.first, 'itemId');
          }
        }
      }
    }
  }

  Future<void> load() async {
    await perform(fetch);
  }

  Future<void> process() async {
    await perform(() async {
      quote = await widget.services.quotations.process(widget.quotationId);
      await fetch();
    });
  }

  Future<void> correct(JsonObject field) async {
    final result = await dataDialog(
      context,
      'Verificar: ${fieldName(textOf(field, 'fieldPath'))}',
      [
        ('value', 'Valor verificado', textOf(field, 'currentValue')),
        ('reason', 'Motivo y evidencia de la corrección', ''),
      ],
    );
    if (result == null) return;
    await perform(() async {
      await widget.services.quotations.correct(
        quote!,
        textOf(field, 'fieldId'),
        result['value']!,
        result['reason']!,
      );
      await fetch();
    });
  }

  Future<void> addSpec(JsonObject line) async {
    final result = await dataDialog(
      context,
      'Registrar especificación del PDF',
      [
        (
          'name',
          'Nombre exacto del requisito',
          widget.request.requirements.isEmpty
              ? ''
              : textOf(widget.request.requirements.first, 'name'),
        ),
        ('value', 'Valor en el documento', ''),
        ('unitOfMeasure', 'Unidad', ''),
        ('sourcePageNumber', 'Página de origen', '1'),
        ('sourceTextReference', 'Texto de evidencia del PDF', ''),
        ('reason', 'Motivo del registro', ''),
      ],
    );
    if (result == null) return;
    final page = int.tryParse(result['sourcePageNumber']!);
    if (page == null || page <= 0) {
      setState(
        () => error = const ApiFailure(
          'La página debe ser un entero mayor a cero.',
        ),
      );
      return;
    }
    await perform(() async {
      await widget.services.quotations.addSpecification(
        quote!,
        textOf(line, 'lineId'),
        {...result, 'sourcePageNumber': page},
      );
      await fetch();
    });
  }

  Future<void> confirm() async {
    if (!mappingsReviewed) {
      setState(
        () => error = const ApiFailure(
          'Verifica las asignaciones antes de confirmar.',
        ),
      );
      return;
    }
    await perform(() async {
      await widget.services.quotations.confirm(quote!, mappings);
      await fetch();
      notice('Cotización verificada.');
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de cotización'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          ErrorNotice(error, onRetry: load),
          if (quote != null) ...[
            InfoCard(
              title: textOf(quote!.data, 'fileName'),
              children: [
                StatusChip(quote!.status),
                Text(
                  'Proveedor: ${textOf(quote!.data, 'supplierBusinessName')}',
                ),
                Text('RUC: ${textOf(quote!.data, 'supplierTaxIdentifier')}'),
                Text(
                  'Total: ${money(quote!.total, textOf(quote!.data, 'currency'))}',
                ),
                Text(
                  'Entrega: ${quote!.data['deliveryLeadTimeDays'] ?? 'no indicada'} días · Vigencia: ${dateLabel(textOf(quote!.data, 'validUntil'))}',
                ),
                if ([
                  'Uploaded',
                  'Rejected',
                  'Processing',
                ].contains(quote!.status))
                  FilledButton(
                    onPressed: busy ? null : process,
                    child: Text(
                      quote!.status == 'Uploaded'
                          ? 'Procesar documento con IA'
                          : 'Reintentar procesamiento',
                    ),
                  ),
                if (quote!.status == 'Rejected')
                  Text(textOf(quote!.data, 'rejectionReason')),
                if (quote!.status == 'Processing')
                  const Text(
                    'Si otra sesión lo procesa, espera. El servidor solo admite recuperar procesos detenidos por más de dos minutos.',
                  ),
              ],
            ),
            if (quote!.status != 'Uploaded') ...[
              SwitchListTile(
                title: const Text('Mostrar todos los campos y su evidencia'),
                value: allFields,
                onChanged: (v) => setState(() => allFields = v),
              ),
              const Text(
                'Corrige únicamente datos sustentados en el PDF. Los campos obligatorios pendientes bloquean la confirmación.',
              ),
              for (final field in visibleFields()) fieldCard(field),
              for (final line in quote!.lines)
                InfoCard(
                  title:
                      'Línea ${line['lineNumber']}: ${textOf(line, 'description')}',
                  children: [
                    Text(
                      '${line['quantity'] ?? '—'} ${textOf(line, 'unitOfMeasure')} · ${money(line['unitPrice'] as num?, textOf(quote!.data, 'currency'))}',
                    ),
                    for (final s in objectsOf(line['specifications']))
                      Text(
                        '${textOf(s, 'name')}: ${textOf(s, 'value')} ${textOf(s, 'unitOfMeasure')}',
                      ),
                    if (quote!.status == 'RequiresVerification') ...[
                      TextButton.icon(
                        onPressed: busy ? null : () => addSpec(line),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Añadir especificación con evidencia',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'mapping-${textOf(line, 'lineId')}-${mappings[textOf(line, 'lineId')]}',
                        ),
                        initialValue: mappings[textOf(line, 'lineId')],
                        isExpanded: true,
                        decoration: fieldDecoration(
                          'Ítem solicitado que cubre esta línea',
                        ),
                        items: widget.request.items
                            .map(
                              (i) => DropdownMenuItem(
                                value: textOf(i, 'itemId'),
                                child: Text(
                                  '${textOf(i, 'description')} · ${i['quantity']} ${textOf(i, 'unitOfMeasure')}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                mappings[textOf(line, 'lineId')] = v!;
                                mappingsReviewed = false;
                              }),
                      ),
                    ],
                  ],
                ),
              if (quote!.status == 'RequiresVerification') ...[
                CheckboxListTile(
                  title: const Text(
                    'He revisado la correspondencia entre las líneas y los ítems solicitados',
                  ),
                  value: mappingsReviewed,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => mappingsReviewed = v!),
                ),
                FilledButton(
                  onPressed:
                      busy ||
                          !quote!.canConfirm ||
                          !mappingsReviewed ||
                          !quote!.lines.every(
                            (line) => widget.request.items.any(
                              (item) =>
                                  textOf(item, 'itemId') ==
                                  mappings[textOf(line, 'lineId')],
                            ),
                          )
                      ? null
                      : confirm,
                  child: const Text('Confirmar cotización verificada'),
                ),
              ],
              if (quote!.verified)
                const Text(
                  'La cotización está verificada y sus datos no se pueden editar.',
                ),
            ],
          ],
        ],
      ),
    ),
  );
  List<JsonObject> visibleFields() {
    final fields = [...quote!.fields]
      ..sort(
        (a, b) => (a['status'] == 'Unresolved' ? 0 : 1).compareTo(
          b['status'] == 'Unresolved' ? 0 : 1,
        ),
      );
    return allFields
        ? fields
        : fields
              .where(
                (f) =>
                    f['isRequired'] == true ||
                    f['status'] == 'Unresolved' ||
                    textOf(f, 'fieldPath').startsWith('supplier.'),
              )
              .toList();
  }

  Widget fieldCard(JsonObject f) => InfoCard(
    title: fieldName(textOf(f, 'fieldPath')),
    children: [
      StatusChip(textOf(f, 'status')),
      SelectableText(
        textOf(f, 'currentValue').isEmpty
            ? 'Sin dato'
            : textOf(f, 'currentValue'),
      ),
      Text(
        'Página ${f['sourcePageNumber']} · Confianza ${(numberOf(f, 'confidence') * 100).toStringAsFixed(0)}%',
      ),
      SelectableText(textOf(f, 'sourceTextReference')),
      Text('Original: ${textOf(f, 'originalValue')}'),
      if (quote!.status == 'RequiresVerification' &&
          Quotation.editable(textOf(f, 'fieldPath')))
        TextButton(
          onPressed: busy ? null : () => correct(f),
          child: const Text('Verificar / corregir con evidencia'),
        ),
      for (final c in objectsOf(f['corrections']))
        Text(
          'Corrección: ${textOf(c, 'previousValue')} → ${textOf(c, 'correctedValue')} · ${textOf(c, 'reason')} · ${dateLabel(textOf(c, 'correctedAt'), time: true)}',
        ),
    ],
  );
}

String fieldName(String path) {
  const names = {
    'supplier.businessName': 'Razón social',
    'supplier.taxIdentifier': 'RUC del proveedor',
    'currency': 'Moneda',
    'deliveryLeadTimeDays': 'Plazo de entrega (días)',
    'validUntil': 'Válida hasta',
  };
  return names[path] ??
      path
          .replaceAll('unitPrice', 'precio unitario')
          .replaceAll('unitOfMeasure', 'unidad')
          .replaceAll('quantity', 'cantidad')
          .replaceAll('description', 'descripción')
          .replaceAll('specifications', 'especificaciones')
          .replaceAll('lines', 'líneas');
}
